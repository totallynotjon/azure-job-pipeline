import { SearchConfig } from "./config";
import { AdzunaJobSearchResults } from "./types/adzuna";

const FETCH_TIMEOUT_MS = 10_000;
const MAX_ATTEMPTS = 5;
const BASE_DELAY_MS = 1_000;
const MAX_DELAY_MS = 16_000;
const RESULTS_PER_PAGE = "50";

export interface AdzunaAuth {
  appId: string;
  appKey: string;
  country: string;
}

export class AdzunaHttpError extends Error {
  constructor(
    public readonly status: number,
    public readonly statusText: string,
    public readonly body: string,
    searchId: string,
  ) {
    super(`Adzuna ${searchId} HTTP ${status} ${statusText}: ${body}`);
    this.name = "AdzunaHttpError";
  }
}

export interface RetryAttemptInfo {
  attempt: number;
  nextDelayMs: number;
  error: string;
}

export type RetryLogger = (info: RetryAttemptInfo) => void;

function buildSearchUrl(auth: AdzunaAuth, search: SearchConfig): URL {
  const url = new URL(
    `https://api.adzuna.com/v1/api/jobs/${auth.country}/search/1`,
  );
  url.searchParams.set("app_id", auth.appId);
  url.searchParams.set("app_key", auth.appKey);
  url.searchParams.set("what", search.what);
  if (search.where) url.searchParams.set("where", search.where);
  url.searchParams.set("results_per_page", RESULTS_PER_PAGE);
  url.searchParams.set("max_days_old", String(search.maxDaysOld ?? 1));
  return url;
}

function isRetryableStatus(status: number): boolean {
  return status >= 500 || status === 429;
}

function isRetryable(err: unknown): boolean {
  if (err instanceof AdzunaHttpError) return isRetryableStatus(err.status);
  if (err instanceof Error) {
    if (err.name === "AbortError" || err.name === "TimeoutError") return true;
    // `fetch failed` is the message Node's undici throws for network errors (DNS, ECONNRESET, etc.)
    if (err.message.includes("fetch failed")) return true;
  }
  return false;
}

function backoffDelay(attempt: number): number {
  const exponential = Math.min(
    BASE_DELAY_MS * 2 ** (attempt - 1),
    MAX_DELAY_MS,
  );
  const jitter = 0.7 + Math.random() * 0.6;
  return Math.round(exponential * jitter);
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export async function fetchAdzunaWithRetry(
  auth: AdzunaAuth,
  search: SearchConfig,
  onRetry?: RetryLogger,
): Promise<AdzunaJobSearchResults> {
  const url = buildSearchUrl(auth, search);

  let lastError: unknown;
  for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
    try {
      const response = await fetch(url, {
        signal: AbortSignal.timeout(FETCH_TIMEOUT_MS),
      });
      if (!response.ok) {
        const body = (await response.text()).slice(0, 500);
        throw new AdzunaHttpError(
          response.status,
          response.statusText,
          body,
          search.id,
        );
      }
      return (await response.json()) as AdzunaJobSearchResults;
    } catch (err) {
      lastError = err;
      if (attempt === MAX_ATTEMPTS || !isRetryable(err)) throw err;
      const delay = backoffDelay(attempt);
      onRetry?.({
        attempt,
        nextDelayMs: delay,
        error: err instanceof Error ? err.message : String(err),
      });
      await sleep(delay);
    }
  }
  throw lastError;
}
