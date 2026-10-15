/** Quotas, abuse limits and payload limits (plan §7.6, contract §1–§2). */

import { HOUR_MS, MINUTE_MS } from "../util/time.js";
import type { RateClass } from "./tasks.js";

export const QUOTA = Object.freeze({
  creditsPerMonth: 250,
  /** Brand-new users may spend at most this many credits in their first 24 h. */
  firstDayCredits: 50,
  firstDayWindowMs: 24 * HOUR_MS,
  /** Hidden per-user cost cap per month (micro-USD). Surfaces as `quota_exceeded`. */
  monthlyCostCapMicros: 6_000_000,
});

export const RATE_LIMITS: Readonly<Record<RateClass, { limit: number; windowMs: number }>> =
  Object.freeze({
    chat: { limit: 12, windowMs: MINUTE_MS }, // includes tool rounds
    task: { limit: 6, windowMs: MINUTE_MS },
  });

export const CONCURRENCY: Readonly<Record<RateClass, number>> = Object.freeze({ chat: 1, task: 2 });

/** Leases outlive the function timeout so a crashed call frees its slot eventually. */
export const LEASE_TTL_MS: Readonly<Record<RateClass, number>> = Object.freeze({
  chat: 11 * MINUTE_MS,
  task: 10 * MINUTE_MS,
});

/** Suggested back-off when the concurrency limit or an in-flight duplicate blocks a call. */
export const BUSY_RETRY_AFTER_MS = 3_000;

export const IDEMPOTENCY = Object.freeze({
  ttlMs: HOUR_MS,
  /** Free re-runs of a completed request whose response was lost. */
  maxFreeReplays: 2,
});

export const GLOBAL_SPEND = Object.freeze({
  defaultDailyBudgetUsd: 50,
  /** At this fraction of the daily budget, tasks with `pauseAtSoftLimit` pause. */
  softLimitFraction: 0.8,
  shards: 10,
  configCacheMs: 30_000,
  spendCacheMs: 15_000,
});

export const PAYLOAD = Object.freeze({
  maxCategories: 150,
  maxCategoryName: 40,
  maxAccounts: 20,
  maxAccountName: 40,
  maxId: 32,
  categorize: {
    maxBodyBytes: 96 * 1024,
    maxCorrections: 20,
    maxCorrectionText: 200,
    minTransactions: 1,
    maxTransactions: 50,
    maxTransactionText: 200,
  },
  quickAdd: { maxBodyBytes: 48 * 1024, minText: 1, maxText: 300 },
  receipt: {
    // 2 MB of JPEG is ~2.8 MB of base64, plus categories.
    maxBodyBytes: 3 * 1024 * 1024,
    maxImageBytes: 2 * 1024 * 1024,
    maxLongEdgePx: 2576,
  },
  insights: {
    maxBodyBytes: 64 * 1024,
    maxMonthOverMonth: 40,
    maxAnomalies: 20,
    maxSubscriptions: 30,
    maxBudgetPace: 40,
    maxGoals: 10,
    maxText: 80,
  },
  budgets: { maxBodyBytes: 64 * 1024, maxLines: 60, maxText: 80 },
  emptyPayload: { maxBodyBytes: 4 * 1024 },
});

/** Business-rule bounds on model output (the output schemas themselves carry no bounds). */
export const OUTPUT = Object.freeze({
  maxMerchant: 60,
  maxNote: 120,
  maxQuestion: 200,
  maxReceiptLineItems: 100,
  maxLineDescription: 80,
  maxInsights: 6,
  maxInsightTitle: 120,
  maxInsightBody: 600,
  maxRationale: 300,
  maxSummary: 600,
  minRuleConfidence: 0.7,
  maxDaysAgo: 366,
});

export const CHAT = Object.freeze({
  maxBodyBytes: 1024 * 1024,
  maxUserTextTurns: 24,
  maxEstimatedTokens: 60_000,
  /** Rough bytes→tokens ratio used for the conversation-length estimate. */
  bytesPerToken: 4,
  maxQuestionChars: 2000,
  maxContextBytes: 8 * 1024,
  maxToolResultBytes: 8 * 1024,
  maxToolResultsTotalBytes: 32 * 1024,
  /** After this many tool rounds in one user turn the proxy sends `tool_choice: none`. */
  maxToolRounds: 6,
  /** max_tokens for the single retry when the output limit cut a tool call. */
  retryMaxTokens: 32768,
  heartbeatMs: 15_000,
});
