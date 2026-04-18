import { app, InvocationContext, Timer } from "@azure/functions";

export async function ingestJobs(
  myTimer: Timer,
  context: InvocationContext
): Promise<void> {
  context.log("fn-ingest-jobs stub invoked", {
    invocationId: context.invocationId,
    timestamp: new Date().toISOString(),
    isPastDue: myTimer.isPastDue,
  });
}

app.timer("ingestJobs", {
  schedule: "0 */5 * * * *",
  handler: ingestJobs,
});
