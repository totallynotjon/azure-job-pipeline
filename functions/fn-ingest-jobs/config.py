import json
import os


def read_config():
    app_id = os.environ.get("ADZUNA_APP_ID")
    app_key = os.environ.get("ADZUNA_APP_KEY")
    country = os.environ.get("ADZUNA_COUNTRY", "us")
    searches_raw = os.environ.get("ADZUNA_SEARCHES")
    storage_account = os.environ.get("RAW_JOBS_STORAGE_ACCOUNT")
    container = os.environ.get("RAW_JOBS_CONTAINER")

    if not app_id or not app_key:
        raise ValueError("ADZUNA_APP_ID and ADZUNA_APP_KEY must be set")
    if not searches_raw:
        raise ValueError("ADZUNA_SEARCHES must be set (JSON array)")
    if not storage_account or not container:
        raise ValueError("RAW_JOBS_STORAGE_ACCOUNT and RAW_JOBS_CONTAINER must be set")

    searches = json.loads(searches_raw)
    if not isinstance(searches, list) or len(searches) == 0:
        raise ValueError("ADZUNA_SEARCHES must be a non-empty JSON array")

    for i, s in enumerate(searches):
        if not isinstance(s, dict):
            raise ValueError(f"ADZUNA_SEARCHES[{i}] must be an object")
        for key in ("id", "what"):
            if key not in s or not isinstance(s[key], str):
                raise ValueError(f"ADZUNA_SEARCHES[{i}].{key} must be a string")
        if "where" in s and not isinstance(s["where"], str):
            raise ValueError(f"ADZUNA_SEARCHES[{i}].where must be a string")

    return {
        "app_id": app_id,
        "app_key": app_key,
        "country": country,
        "searches": searches,
        "storage_account": storage_account,
        "container": container,
    }
