export interface SearchConfig {
  id: string;
  what: string;
  where: string;
  maxDaysOld?: number;
}

export interface IngestConfig {
  appId: string;
  appKey: string;
  country: string;
  searches: SearchConfig[];
  storageAccount: string;
  container: string;
}

const SEARCH_ID_PATTERN = /^[a-z0-9-]+$/;

export function validateSearches(raw: unknown): SearchConfig[] {
  if (!Array.isArray(raw)) {
    throw new Error("ADZUNA_SEARCHES must be a JSON array");
  }
  return raw.map((item, idx) => {
    if (typeof item !== "object" || item === null) {
      throw new Error(`ADZUNA_SEARCHES[${idx}] must be an object`);
    }
    const { id, what, where, maxDaysOld } = item as Record<string, unknown>;
    if (typeof id !== "string" || !SEARCH_ID_PATTERN.test(id)) {
      throw new Error(
        `ADZUNA_SEARCHES[${idx}].id must be a string matching ${SEARCH_ID_PATTERN}`,
      );
    }
    if (typeof what !== "string" || what.length === 0) {
      throw new Error(
        `ADZUNA_SEARCHES[${idx}].what must be a non-empty string`,
      );
    }
    if (typeof where !== "string") {
      throw new Error(
        `ADZUNA_SEARCHES[${idx}].where must be a string (may be empty)`,
      );
    }
    if (
      maxDaysOld !== undefined &&
      (typeof maxDaysOld !== "number" ||
        !Number.isFinite(maxDaysOld) ||
        maxDaysOld < 1)
    ) {
      throw new Error(
        `ADZUNA_SEARCHES[${idx}].maxDaysOld must be a positive finite number`,
      );
    }
    return { id, what, where, maxDaysOld } as SearchConfig;
  });
}

export function readConfig(): IngestConfig {
  const appId = process.env.ADZUNA_APP_ID;
  const appKey = process.env.ADZUNA_APP_KEY;
  const country = process.env.ADZUNA_COUNTRY ?? "us";
  const searchesRaw = process.env.ADZUNA_SEARCHES;
  const storageAccount = process.env.RAW_JOBS_STORAGE_ACCOUNT;
  const container = process.env.RAW_JOBS_CONTAINER;

  if (!appId || !appKey) {
    throw new Error("ADZUNA_APP_ID and ADZUNA_APP_KEY must be set");
  }
  if (!searchesRaw) {
    throw new Error("ADZUNA_SEARCHES must be set (JSON array)");
  }
  if (!storageAccount || !container) {
    throw new Error(
      "RAW_JOBS_STORAGE_ACCOUNT and RAW_JOBS_CONTAINER must be set",
    );
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(searchesRaw);
  } catch (err) {
    throw new Error(
      `ADZUNA_SEARCHES is not valid JSON: ${(err as Error).message}`,
    );
  }
  const searches = validateSearches(parsed);

  return { appId, appKey, country, searches, storageAccount, container };
}
