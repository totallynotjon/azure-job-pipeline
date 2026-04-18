import { app, InvocationContext, Timer } from "@azure/functions";

export async function ingestJobs(
  myTimer: Timer,
  context: InvocationContext,
): Promise<void> {
  context.log("fn-ingest-jobs stub invoked", {
    invocationId: context.invocationId,
    timestamp: new Date().toISOString(),
    isPastDue: myTimer.isPastDue,
  });

  const stuff = 3;
}

app.timer("ingestJobs", {
  schedule: "0 0 */2 * * *",
  handler: ingestJobs,
});
