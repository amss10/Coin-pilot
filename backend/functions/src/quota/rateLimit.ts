/** Sliding-window rate limiting over a per-user log of request timestamps. */

export interface RateWindow {
  limit: number;
  windowMs: number;
}

/** Keeps only timestamps inside the window, oldest first. */
export function pruneLog(log: readonly number[], now: number, windowMs: number): number[] {
  return log.filter((t) => t > now - windowMs && t <= now).sort((a, b) => a - b);
}

export type RateDecision = { allowed: true; log: number[] } | { allowed: false; retryAfterMs: number };

/** Allows the request when fewer than `limit` requests happened in the last `windowMs`. */
export function checkRate(log: readonly number[], now: number, window: RateWindow): RateDecision {
  const recent = pruneLog(log, now, window.windowMs);
  if (recent.length >= window.limit) {
    const oldestThatMustExpire = recent[recent.length - window.limit] ?? now;
    return { allowed: false, retryAfterMs: Math.max(1, oldestThatMustExpire + window.windowMs - now) };
  }
  return { allowed: true, log: [...recent, now] };
}
