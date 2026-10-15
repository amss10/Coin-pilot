/**
 * Idempotency keys (`usage/{uid}/idem/{key}`, 1 h TTL, keys only). Retries with the same key
 * are never charged twice:
 * - new or previously refunded key → normal, charged call;
 * - same key still in flight → `rate_limited` (wait for the first call);
 * - completed key → a free re-run (the response is not stored), at most `maxFreeReplays`
 *   times, after which the key is rejected.
 */

import { BUSY_RETRY_AFTER_MS, IDEMPOTENCY } from "../config/limits.js";
import type { TaskName } from "../config/tasks.js";
import { AppError } from "../errors.js";
import type { IdemRecord } from "./store.js";

export type IdemDecision = { kind: "new" } | { kind: "replay"; previous: IdemRecord };

export function evaluateIdempotency(rec: IdemRecord | null, task: TaskName, now: number): IdemDecision {
  if (rec === null || rec.expiresAt <= now) return { kind: "new" };
  if (rec.task !== task) {
    throw new AppError("invalid_input", "This request id was already used for a different request.", {
      reason: "idempotency_task_mismatch",
      issues: [{ path: "idempotencyKey", message: "already used for a different request" }],
    });
  }
  // A pending call whose lease expired was abandoned (its credits were charged on expiry).
  const state = rec.state === "pending" && rec.pendingUntil <= now ? "done" : rec.state;
  switch (state) {
    case "refunded":
      return { kind: "new" };
    case "pending":
      throw new AppError("rate_limited", "This request is already in progress.", {
        retryAfterMs: BUSY_RETRY_AFTER_MS,
        reason: "idempotency_in_flight",
      });
    case "done":
      if (rec.replays >= IDEMPOTENCY.maxFreeReplays) {
        throw new AppError("invalid_input", "This request id was already used.", {
          reason: "idempotency_exhausted",
          issues: [{ path: "idempotencyKey", message: "already used; send a new key" }],
        });
      }
      return { kind: "replay", previous: rec };
  }
}

export function pendingRecord(decision: IdemDecision, task: TaskName, now: number, pendingUntil: number): IdemRecord {
  if (decision.kind === "replay") {
    return { ...decision.previous, state: "pending", replays: decision.previous.replays + 1, pendingUntil };
  }
  return { task, state: "pending", replays: 0, createdAt: now, pendingUntil, expiresAt: now + IDEMPOTENCY.ttlMs };
}

export function finishedRecord(rec: IdemRecord | null, state: "done" | "refunded"): IdemRecord | undefined {
  return rec === null ? undefined : { ...rec, state };
}
