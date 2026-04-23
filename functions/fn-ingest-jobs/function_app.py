import logging
from datetime import datetime, timezone

import azure.durable_functions as df
import azure.functions as func

from adzuna import fetch_adzuna
from config import read_config

app = df.DFApp()


# ---------- Client (timer) ----------
@app.timer_trigger(schedule="0 0 */6 * * *", arg_name="timer", run_on_startup=False)
@app.durable_client_input(client_name="client")
async def ingest_timer(timer: func.TimerRequest, client: df.DurableOrchestrationClient) -> None:
    cfg = read_config()
    now = datetime.now(timezone.utc)
    run_id = now.strftime("%Y-%m-%dT%H-%M-%S-%f")[:-3] + "Z"

    logging.info(
        "ingest_timer run started",
        extra={"custom_dimensions": {
            "run_id": run_id,
            "search_count": len(cfg["searches"]),
            "country": cfg["country"],
        }},
    )

    started = 0
    skipped = 0
    failures = []

    for search in cfg["searches"]:
        try:
            data = fetch_adzuna(cfg["app_id"], cfg["app_key"], cfg["country"], search)
            for job in data.get("results", []):
                instance_id = _instance_id("adzuna", job.get("id"))
                try:
                    await client.start_new(
                        orchestration_function_name="job_pipeline",
                        instance_id=instance_id,
                        client_input={"source": "adzuna", "search_id": search["id"], "raw": job},
                    )
                    started += 1
                except Exception as exc:
                    # Most common cause: an instance with this id is already running
                    # (prior run for same Adzuna job). Treat as dedup hit.
                    skipped += 1
                    logging.info(
                        "skipped duplicate orchestration",
                        extra={"custom_dimensions": {
                            "instance_id": instance_id,
                            "error": str(exc),
                        }},
                    )
        except Exception as exc:
            logging.error(
                "Adzuna search failed",
                extra={"custom_dimensions": {"search_id": search["id"], "error": str(exc)}},
            )
            failures.append({"search_id": search["id"], "error": str(exc)})

    if failures and len(failures) == len(cfg["searches"]):
        raise RuntimeError(f"All {len(failures)} Adzuna searches failed")

    logging.info(
        "ingest_timer run completed",
        extra={"custom_dimensions": {
            "run_id": run_id,
            "started": started,
            "skipped": skipped,
            "search_failures": len(failures),
        }},
    )


# ---------- Orchestrator ----------
@app.orchestration_trigger(context_name="ctx")
def job_pipeline(ctx: df.DurableOrchestrationContext):
    job_input = ctx.get_input()

    filtered = yield ctx.call_activity("filter_job", job_input)
    if not filtered.get("keep"):
        return {"status": "rejected", "reason": filtered.get("reason")}

    persisted = yield ctx.call_activity("persist_to_sql", filtered["job"])
    return {"status": "done", "persisted": persisted}


# ---------- Activities ----------
@app.activity_trigger(input_name="jobInput")
def filter_job(jobInput: dict) -> dict:
    # Phase 2 will add real filter rules (location, salary floor, keyword exclusions).
    # For now: normalize the raw Adzuna payload into the shape SQL expects and keep everything.
    raw = jobInput.get("raw", {})
    normalized = {
        "source": jobInput.get("source", "adzuna"),
        "source_job_id": str(raw.get("id")),
        "job_url": raw.get("redirect_url"),
        "title": raw.get("title"),
        "company_name": (raw.get("company") or {}).get("display_name"),
        "location_display": (raw.get("location") or {}).get("display_name"),
        "latitude": raw.get("latitude"),
        "longitude": raw.get("longitude"),
        "contract_type": raw.get("contract_type"),
        "category_tag": (raw.get("category") or {}).get("tag"),
        "category_label": (raw.get("category") or {}).get("label"),
        "salary_min": raw.get("salary_min"),
        "salary_max": raw.get("salary_max"),
        "salary_is_predicted": raw.get("salary_is_predicted") in ("1", 1, True),
        "description": raw.get("description"),
        "posted_at": raw.get("created"),
    }
    return {"keep": True, "job": normalized}


@app.activity_trigger(input_name="job")
def persist_to_sql(job: dict) -> dict:
    # STUB: SQL MI access not wired yet (next PR). For now, log what we would have written.
    logging.info(
        "persist_to_sql stub",
        extra={"custom_dimensions": {
            "source": job.get("source"),
            "source_job_id": job.get("source_job_id"),
            "title": job.get("title"),
            "company": job.get("company_name"),
        }},
    )
    return {"stub": True, "source_job_id": job.get("source_job_id")}


# ---------- Helpers ----------
def _instance_id(source: str, source_job_id) -> str:
    return f"{source}-{source_job_id}"
