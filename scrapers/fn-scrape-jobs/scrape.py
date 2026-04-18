"""Scrape jobs from one source, write raw JSON to blob storage."""
import os
import uuid
from datetime import datetime, timezone

from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient, ContentSettings
from jobspy import scrape_jobs

JOBSPY_VERSION = "1.1.80"


def main() -> None:
    storage_account = os.environ["STORAGE_ACCOUNT_NAME"]
    container_name = os.environ["STORAGE_CONTAINER_NAME"]
    source = os.environ.get("SOURCE", "indeed")
    search_term = os.environ.get("SEARCH_TERM", "site reliability engineer")
    location = os.environ.get("LOCATION", "Remote")
    results_wanted = int(os.environ.get("RESULTS_WANTED", "25"))
    hours_old = int(os.environ.get("HOURS_OLD", "72"))

    run_id = str(uuid.uuid4())
    scrape_utc = datetime.now(timezone.utc)

    print(f"[{run_id}] scrape start source={source} term={search_term!r} loc={location!r}")

    df = scrape_jobs(
        site_name=[source],
        search_term=search_term,
        location=location,
        results_wanted=results_wanted,
        hours_old=hours_old,
        country_indeed="USA",
    )
    job_count = len(df)
    print(f"[{run_id}] scraped {job_count} jobs")

    payload = df.to_json(orient="records", date_format="iso")

    blob_path = (
        f"{source}/"
        f"{scrape_utc:%Y}/{scrape_utc:%m}/{scrape_utc:%d}/"
        f"{run_id}.json"
    )

    credential = DefaultAzureCredential()
    service = BlobServiceClient(
        account_url=f"https://{storage_account}.blob.core.windows.net",
        credential=credential,
    )
    blob = service.get_blob_client(container=container_name, blob=blob_path)
    blob.upload_blob(
        payload,
        overwrite=False,
        content_settings=ContentSettings(content_type="application/json"),
        metadata={
            "source": source,
            "scrape_utc": scrape_utc.isoformat(),
            "job_count": str(job_count),
            "run_id": run_id,
            "jobspy_version": JOBSPY_VERSION,
            "search_term": search_term,
            "location": location,
        },
    )
    print(f"[{run_id}] wrote blob: {container_name}/{blob_path}")


if __name__ == "__main__":
    main()
