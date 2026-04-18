import { app, InvocationContext, Timer } from "@azure/functions";
import { DefaultAzureCredential } from "@azure/identity";
import { BlobServiceClient } from "@azure/storage-blob";
import { AdzunaJobSearchResults } from "../types/adzuna";

interface SearchConfig {
  id: string;
  what: string;
  where: string;
  maxDaysOld?: number;
}

function readConfig() {
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

  const searches: SearchConfig[] = JSON.parse(searchesRaw);

  return { appId, appKey, country, searches, storageAccount, container };
}

async function fetchAdzuna(
  appId: string,
  appKey: string,
  country: string,
  search: SearchConfig,
): Promise<AdzunaJobSearchResults> {
  const url = new URL(`https://api.adzuna.com/v1/api/jobs/${country}/search/1`);
  url.searchParams.set("app_id", appId);
  url.searchParams.set("app_key", appKey);
  url.searchParams.set("what", search.what);
  if (search.where) url.searchParams.set("where", search.where);
  url.searchParams.set("results_per_page", "50");
  url.searchParams.set("max_days_old", String(search.maxDaysOld ?? 1));

  const response = await fetch(url);
  if (!response.ok) {
    const body = await response.text();
    throw new Error(
      `Adzuna ${search.id} failed: ${response.status} ${response.statusText} — ${body}`,
    );
  }
  return (await response.json()) as AdzunaJobSearchResults;
}

function buildBlobPath(searchId: string, runId: string): string {
  const now = new Date();
  const yyyy = now.getUTCFullYear();
  const mm = String(now.getUTCMonth() + 1).padStart(2, "0");
  const dd = String(now.getUTCDate()).padStart(2, "0");
  return `adzuna/${searchId}/${yyyy}/${mm}/${dd}/${runId}.json`;
}

export async function ingestJobs(
  _myTimer: Timer,
  context: InvocationContext,
): Promise<void> {
  const cfg = readConfig();

  const credential = new DefaultAzureCredential();
  const blobServiceClient = new BlobServiceClient(
    `https://${cfg.storageAccount}.blob.core.windows.net`,
    credential,
  );
  const containerClient = blobServiceClient.getContainerClient(cfg.container);

  const runId = new Date().toISOString().replace(/[:.]/g, "-");

  for (const search of cfg.searches) {
    const started = Date.now();
    const data = await fetchAdzuna(cfg.appId, cfg.appKey, cfg.country, search);

    const blobPath = buildBlobPath(search.id, runId);
    const body = JSON.stringify(data);
    const blobClient = containerClient.getBlockBlobClient(blobPath);
    await blobClient.uploadData(Buffer.from(body), {
      blobHTTPHeaders: { blobContentType: "application/json" },
      metadata: {
        source: "adzuna",
        searchid: search.id,
        what: search.what,
        where: search.where,
        count: String(data.count ?? 0),
        ingestedat: new Date().toISOString(),
      },
    });

    context.log("Ingested Adzuna search", {
      searchId: search.id,
      resultCount: data.results.length,
      totalCount: data.count,
      blobPath,
      durationMs: Date.now() - started,
    });
  }
}

app.timer("ingestJobs", {
  schedule: "0 0 */6 * * *",
  handler: ingestJobs,
});
