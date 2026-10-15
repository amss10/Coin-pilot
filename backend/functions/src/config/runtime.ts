/** Cloud Functions runtime settings. The region lives here and only here. */

export const REGION = "us-central1";

/** Instance caps bound the worst-case spend rate; no minInstances in code (see README). */
export const RUNTIME = Object.freeze({
  globalMaxInstances: 20,
  task: { maxInstances: 20, timeoutSeconds: 540, memory: "512MiB", concurrency: 40 },
  receipt: { maxInstances: 10, timeoutSeconds: 540, memory: "1GiB", concurrency: 10 },
  account: { maxInstances: 5, timeoutSeconds: 60, memory: "256MiB", concurrency: 80 },
  chat: { maxInstances: 20, timeoutSeconds: 600, memory: "512MiB", concurrency: 40 },
} as const);

/** Anthropic SDK client settings (per-request timeout in ms; the SDK retries 429/5xx). */
export const SDK = Object.freeze({
  taskTimeoutMs: 240_000,
  chatTimeoutMs: 570_000,
  maxRetries: 1,
});
