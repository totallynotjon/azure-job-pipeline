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


@app.timer_trigger(schedule="0 0 */6 * * *", arg_name="timer", run_on_startup=False)
@app.durable_client_input(client_name="client")
async def ingest_timer(
    timer: func.TimerRequest, client: df.DurableOrchestrationClient
) -> None:
    cfg = read_config()
    run_id = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")

    total = 0
    for search in cfg["searches"]:
        data = fetch_adzuna(cfg["app_id"], cfg["app_key"], cfg["country"], search)
        results = data.get("results", [])
        logging.info("search=%s returned %d results", search["id"], len(results))

        for job in results:
            instance_id = f"job-{job.get('id', '')}"
            job_input = {
                "source": "adzuna",
                "searchId": search["id"],
                "runId": run_id,
                "raw": job,
            }
            try:
                await client.start_new(
                    "job_pipeline", instance_id=instance_id, client_input=job_input
                )
                total += 1
            except Exception:
                logging.warning(
                    "orchestration %s already running, skipping", instance_id
                )

    logging.info("started %d orchestrations for run %s", total, run_id)


@app.orchestration_trigger(context_name="context")
def job_pipeline(context: df.DurableOrchestrationContext):
    job_input = context.get_input()
    filtered = yield context.call_activity("filter_job", job_input)
    if not filtered.get("keep"):
        return {"status": "rejected", "reason": filtered.get("reason")}
    persisted = yield context.call_activity("persist_to_sql", filtered["job"])
    return {"status": "done", "persisted": persisted}


@app.activity_trigger(input_name="payload")
def filter_job(payload: dict) -> dict:
    raw = payload.get("raw", {})

    title = raw.get("title", "")
    description = raw.get("description", "")
    url = raw.get("redirect_url", "")

    if not url:
        return {"keep": False, "reason": "no url"}

    job = {
        "source": payload.get("source"),
        "source_id": str(raw.get("id", "")),
        "title": title,
        "company": raw.get("company", {}).get("display_name", ""),
        "location": raw.get("location", {}).get("display_name", ""),
        "url": url,
        "description": description,
        "salary_min": raw.get("salary_min"),
        "salary_max": raw.get("salary_max"),
        "posted_date": raw.get("created"),
        "search_id": payload.get("searchId"),
        "run_id": payload.get("runId"),
    }
    return {"keep": True, "job": job}


@app.activity_trigger(input_name="job")
def persist_to_sql(job: dict) -> dict:
    import pyodbc

    conn_str = (
        f"Driver={{ODBC Driver 18 for SQL Server}};"
        f"Server=tcp:{SQL_SERVER}.database.windows.net,1433;"
        f"Database={SQL_DATABASE};"
        f"Authentication=ActiveDirectoryMsi;"
        f"Encrypt=yes;TrustServerCertificate=no;"
    )

    merge_sql = """
    MERGE INTO dbo.Jobs AS target
    USING (SELECT ? AS Url) AS source
    ON target.Url = source.Url
    WHEN NOT MATCHED THEN INSERT (
        Source, SourceId, Title, Company, Location, Url,
        Description, SalaryMin, SalaryMax, PostedDate, SearchId, RunId
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
    """

    with pyodbc.connect(conn_str, timeout=15) as conn:
        with conn.cursor() as cur:
            cur.execute(
                merge_sql,
                job["url"],
                job["source"],
                job["source_id"],
                job["title"],
                job["company"],
                job["location"],
                job["url"],
                job["description"],
                job["salary_min"],
                job["salary_max"],
                job["posted_date"],
                job["search_id"],
                job["run_id"],
            )
            inserted = cur.rowcount
        conn.commit()

    return {"url": job["url"], "inserted": inserted > 0}
