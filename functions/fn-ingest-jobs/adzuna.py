import logging

import requests
from tenacity import (
    before_sleep_log,
    retry,
    retry_if_exception,
    stop_after_attempt,
    wait_exponential_jitter,
)

RESULTS_PER_PAGE = 50
FETCH_TIMEOUT_S = 10


class AdzunaHttpError(Exception):
    def __init__(self, status, body, search_id):
        self.status = status
        self.body = body
        super().__init__(f"Adzuna {search_id} HTTP {status}: {body[:500]}")


def _is_retryable(exc):
    if isinstance(exc, AdzunaHttpError):
        return exc.status >= 500 or exc.status == 429
    return isinstance(exc, (requests.ConnectionError, requests.Timeout))


@retry(
    stop=stop_after_attempt(5),
    wait=wait_exponential_jitter(initial=1, max=16, jitter=2),
    retry=retry_if_exception(_is_retryable),
    reraise=True,
    before_sleep=before_sleep_log(logging.getLogger(__name__), logging.WARNING),
)
def fetch_adzuna(app_id, app_key, country, search):
    params = {
        "app_id": app_id,
        "app_key": app_key,
        "what": search["what"],
        "results_per_page": RESULTS_PER_PAGE,
        "max_days_old": search.get("maxDaysOld", 1),
    }
    if search.get("where"):
        params["where"] = search["where"]

    resp = requests.get(
        f"https://api.adzuna.com/v1/api/jobs/{country}/search/1",
        params=params,
        timeout=FETCH_TIMEOUT_S,
    )
    if not resp.ok:
        raise AdzunaHttpError(resp.status_code, resp.text, search["id"])

    return resp.json()
