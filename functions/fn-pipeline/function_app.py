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
        "Source": payload.get("source"),
        "SourceJobId": str(raw.get("id", "")),
        "JobUrl": url,
        "Title": title,
        "CompanyName": raw.get("company", {}).get("display_name"),
        "LocationDisplay": raw.get("location", {}).get("display_name"),
        "Latitude": raw.get("latitude"),
        "Longitude": raw.get("longitude"),
        "ContractType": raw.get("contract_type"),
        "CategoryTag": raw.get("category", {}).get("tag"),
        "CategoryLabel": raw.get("category", {}).get("label"),
        "SalaryMin": raw.get("salary_min"),
        "SalaryMax": raw.get("salary_max"),
        "SalaryIsPredicted": raw.get("salary_is_predicted"),
        "Description": description,
        "PostedAt": raw.get("created"),
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
    USING (SELECT ? AS Source, ? AS SourceJobId) AS src
    ON target.Source = src.Source AND target.SourceJobId = src.SourceJobId
    WHEN NOT MATCHED THEN INSERT (
        Source, SourceJobId, JobUrl, Title, CompanyName, LocationDisplay,
        Latitude, Longitude, ContractType, CategoryTag, CategoryLabel,
        SalaryMin, SalaryMax, SalaryIsPredicted, Description, PostedAt
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
    """

    with pyodbc.connect(conn_str, timeout=60) as conn:
        with conn.cursor() as cur:
            cur.execute(
                merge_sql,
                job["Source"],
                job["SourceJobId"],
                job["Source"],
                job["SourceJobId"],
                job["JobUrl"],
                job["Title"],
                job["CompanyName"],
                job["LocationDisplay"],
                job["Latitude"],
                job["Longitude"],
                job["ContractType"],
                job["CategoryTag"],
                job["CategoryLabel"],
                job["SalaryMin"],
                job["SalaryMax"],
                job["SalaryIsPredicted"],
                job["Description"],
                job["PostedAt"],
            )
            inserted = cur.rowcount
        conn.commit()

    return {"source": job["Source"], "source_job_id": job["SourceJobId"], "inserted": inserted > 0}
