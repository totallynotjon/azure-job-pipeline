import logging
import os
from datetime import datetime, timezone

import azure.durable_functions as df
import azure.functions as func

from adzuna import fetch_adzuna
from config import read_config

app = df.DFApp()

SQL_SERVER = os.environ.get("SQL_SERVER")
SQL_DATABASE = os.environ.get("SQL_DATABASE")


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


_MERGE_SQL = """
MERGE dbo.Jobs AS target
USING (VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)) AS src (
    Source, SourceJobId, JobUrl, Title, CompanyName,
    LocationDisplay, Latitude, Longitude, ContractType,
    CategoryTag, CategoryLabel, SalaryMin, SalaryMax,
    SalaryIsPredicted, Description, PostedAt
)
ON target.Source = src.Source AND target.SourceJobId = src.SourceJobId
WHEN NOT MATCHED THEN
    INSERT (Source, SourceJobId, JobUrl, Title, CompanyName,
            LocationDisplay, Latitude, Longitude, ContractType,
            CategoryTag, CategoryLabel, SalaryMin, SalaryMax,
            SalaryIsPredicted, Description, PostedAt)
    VALUES (src.Source, src.SourceJobId, src.JobUrl, src.Title, src.CompanyName,
            src.LocationDisplay, src.Latitude, src.Longitude, src.ContractType,
            src.CategoryTag, src.CategoryLabel, src.SalaryMin, src.SalaryMax,
            src.SalaryIsPredicted, src.Description, src.PostedAt);
"""


@app.activity_trigger(input_name="job")
def persist_to_sql(job: dict) -> dict:
    # Lazy import: pyodbc's C extension needs libodbc.so.2 at load time.
    # Keeping it out of module scope so worker indexing doesn't fail if the
    # Flex Consumption image doesn't ship unixODBC — the other functions
    # still register, and an ImportError here surfaces cleanly in logs.
    import pyodbc

    if not SQL_SERVER or not SQL_DATABASE:
        raise RuntimeError("SQL_SERVER and SQL_DATABASE env vars must be set")

    posted_at = None
    if job.get("posted_at"):
        posted_at = datetime.fromisoformat(job["posted_at"].replace("Z", "+00:00"))

    conn_str = (
        "Driver={ODBC Driver 18 for SQL Server};"
        f"Server=tcp:{SQL_SERVER}.database.windows.net,1433;"
        f"Database={SQL_DATABASE};"
        "Authentication=ActiveDirectoryManagedIdentity;"
        "Encrypt=yes;TrustServerCertificate=no;Connection Timeout=30;"
    )

    params = (
        job.get("source"),
        job.get("source_job_id"),
        job.get("job_url"),
        job.get("title"),
        job.get("company_name"),
        job.get("location_display"),
        job.get("latitude"),
        job.get("longitude"),
        job.get("contract_type"),
        job.get("category_tag"),
        job.get("category_label"),
        job.get("salary_min"),
        job.get("salary_max"),
        job.get("salary_is_predicted"),
        job.get("description"),
        posted_at,
    )

    with pyodbc.connect(conn_str) as conn:
        with conn.cursor() as cursor:
            cursor.execute(_MERGE_SQL, params)
            rows_affected = cursor.rowcount
        conn.commit()

    logging.info(
        "persist_to_sql merged",
        extra={"custom_dimensions": {
            "source": job.get("source"),
            "source_job_id": job.get("source_job_id"),
            "inserted": rows_affected,
        }},
    )
    return {"source_job_id": job.get("source_job_id"), "inserted": rows_affected}


# ---------- Helpers ----------
def _instance_id(source: str, source_job_id) -> str:
    return f"{source}-{source_job_id}"
