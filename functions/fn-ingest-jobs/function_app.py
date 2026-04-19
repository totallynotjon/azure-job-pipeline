import json
import logging
from datetime import datetime, timezone

import azure.functions as func
from azure.core.exceptions import ResourceExistsError
from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient, ContentSettings

from adzuna import fetch_adzuna
from config import read_config

app = func.FunctionApp()

_credential = DefaultAzureCredential()
_blob_service_client = None


def _get_container_client(storage_account, container):
    global _blob_service_client
    if _blob_service_client is None:
        _blob_service_client = BlobServiceClient(
            f"https://{storage_account}.blob.core.windows.net",
            credential=_credential,
        )
    return _blob_service_client.get_container_client(container)


@app.timer_trigger(schedule="0 0 */6 * * *", arg_name="timer", run_on_startup=False)
def ingest_jobs(timer: func.TimerRequest) -> None:
    cfg = read_config()
    container_client = _get_container_client(cfg["storage_account"], cfg["container"])

    now = datetime.now(timezone.utc)
    run_id = now.strftime("%Y-%m-%dT%H-%M-%S-%f")[:-3] + "Z"

    logging.info(
        "ingest_jobs run started",
        extra={"custom_dimensions": {
            "run_id": run_id,
            "search_count": len(cfg["searches"]),
            "country": cfg["country"],
        }},
    )

    failures = []
    for search in cfg["searches"]:
        try:
            started = datetime.now(timezone.utc)
            data = fetch_adzuna(cfg["app_id"], cfg["app_key"], cfg["country"], search)
            results = data.get("results", [])

            blob_path = f"adzuna/{search['id']}/{now:%Y}/{now:%m}/{now:%d}/{run_id}.json"
            blob_client = container_client.get_blob_client(blob_path)

            blob_client.upload_blob(
                json.dumps(data),
                content_settings=ContentSettings(content_type="application/json"),
                metadata={
                    "source": "adzuna",
                    "searchid": search["id"],
                    "count": str(data.get("count", 0)),
                    "ingestedat": datetime.now(timezone.utc).isoformat(),
                },
                overwrite=False,
            )

            elapsed = (datetime.now(timezone.utc) - started).total_seconds()
            logging.info(
                "Ingested Adzuna search",
                extra={"custom_dimensions": {
                    "search_id": search["id"],
                    "result_count": len(results),
                    "total_count": data.get("count"),
                    "blob_path": blob_path,
                    "duration_s": elapsed,
                }},
            )
        except ResourceExistsError:
            msg = f"blob already exists for {search['id']} (concurrent run or clock skew)"
            logging.error(msg)
            failures.append({"search_id": search["id"], "error": msg})
        except Exception as exc:
            logging.error(
                "Adzuna search failed",
                extra={"custom_dimensions": {"search_id": search["id"], "error": str(exc)}},
            )
            failures.append({"search_id": search["id"], "error": str(exc)})

    if failures and len(failures) == len(cfg["searches"]):
        raise RuntimeError(f"All {len(failures)} Adzuna searches failed: {json.dumps(failures)}")

    if failures:
        logging.warning(
            "ingest_jobs completed with partial failures",
            extra={"custom_dimensions": {
                "run_id": run_id,
                "failure_count": len(failures),
                "success_count": len(cfg["searches"]) - len(failures),
            }},
        )
    else:
        logging.info(
            "ingest_jobs run completed",
            extra={"custom_dimensions": {
                "run_id": run_id,
                "success_count": len(cfg["searches"]),
            }},
        )
