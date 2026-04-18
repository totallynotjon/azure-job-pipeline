import { app, InvocationContext, Timer } from "@azure/functions";
import { DefaultAzureCredential } from "@azure/identity";
import {
  BlobServiceClient,
  ContainerClient,
  RestError,
} from "@azure/storage-blob";
import { fetchAdzunaWithRetry } from "../adzuna";
import { IngestConfig, SearchConfig, readConfig } from "../config";

const credential = new DefaultAzureCredential();
let cachedBlobServiceClient: BlobServiceClient | undefined;

function getContainerClient(
  storageAccount: string,
  container: string,
): ContainerClient {
  if (!cachedBlobServiceClient) {
    cachedBlobServiceClient = new BlobServiceClient(
      `https://${storageAccount}.blob.core.windows.net`,
      credential,
    );
  }
  return cachedBlobServiceClient.getContainerClient(container);
}

function buildBlobPath(searchId: string, runId: string): string {
  const now = new Date();
  const yyyy = now.getUTCFullYear();
  const mm = String(now.getUTCMonth() + 1).padStart(2, "0");
  const dd = String(now.getUTCDate()).padStart(2, "0");
  return `adzuna/${searchId}/${yyyy}/${mm}/${dd}/${runId}.json`;
}

async function processSearch(
  context: InvocationContext,
  containerClient: ContainerClient,
  cfg: IngestConfig,
  search: SearchConfig,
  runId: string,
): Promise<void> {
  const started = Date.now();
  const data = await fetchAdzunaWithRetry(
    { appId: cfg.appId, appKey: cfg.appKey, country: cfg.country },
    search,
    (info) =>
      context.warn("Adzuna retry", { searchId: search.id, ...info }),
  );
  const results = data.results ?? [];

  const blobPath = buildBlobPath(search.id, runId);
  const blobClient = containerClient.getBlockBlobClient(blobPath);
  const body = JSON.stringify(data);

  try {
    await blobClient.uploadData(Buffer.from(body), {
      blobHTTPHeaders: { blobContentType: "application/json" },
      metadata: {
        source: "adzuna",
        searchid: search.id,
        count: String(data.count ?? 0),
        ingestedat: new Date().toISOString(),
      },
      conditions: { ifNoneMatch: "*" },
    });
  } catch (err) {
    if (err instanceof RestError && err.statusCode === 409) {
      throw new Error(
        `blob ${blobPath} already exists (concurrent run or clock skew)`,
      );
    }
    throw err;
  }

  context.log("Ingested Adzuna search", {
    searchId: search.id,
    resultCount: results.length,
    totalCount: data.count,
    blobPath,
    durationMs: Date.now() - started,
  });
}

export async function ingestJobs(
  _myTimer: Timer,
  context: InvocationContext,
): Promise<void> {
  const cfg = readConfig();
  const containerClient = getContainerClient(cfg.storageAccount, cfg.container);
  const runId = new Date().toISOString().replace(/[:.]/g, "-");

  context.log("ingestJobs run started", {
    runId,
    searchCount: cfg.searches.length,
    country: cfg.country,
  });

  const outcomes = await Promise.allSettled(
    cfg.searches.map((search) =>
      processSearch(context, containerClient, cfg, search, runId),
    ),
  );

  const failures = outcomes.flatMap((outcome, idx) => {
    if (outcome.status === "rejected") {
      const searchId = cfg.searches[idx].id;
      const message =
        outcome.reason instanceof Error
          ? outcome.reason.message
          : String(outcome.reason);
      context.error("Adzuna search failed", { searchId, error: message });
      return [{ searchId, error: message }];
    }
    return [];
  });

  if (failures.length === cfg.searches.length) {
    throw new Error(
      `All ${failures.length} Adzuna searches failed: ${JSON.stringify(failures)}`,
    );
  }
  if (failures.length > 0) {
    context.warn("ingestJobs completed with partial failures", {
      runId,
      failureCount: failures.length,
      successCount: cfg.searches.length - failures.length,
    });
    return;
  }
  context.log("ingestJobs run completed", {
    runId,
    successCount: cfg.searches.length,
  });
}

app.timer("ingestJobs", {
  schedule: "0 0 */6 * * *",
  handler: ingestJobs,
});
