/**
 * Per-task AI configuration: model, effort, max_tokens and credit price. The server owns AI
 * behaviour, so these change without an app release. Every task runs on claude-opus-5-5;
 * moving a task to a cheaper model is a product decision gated on the eval suite.
 */

export type Effort = "low" | "medium" | "high" | "xhigh" | "max";

export const STRUCTURED_TASKS = ["categorize", "quickAdd", "receipt", "insights", "budgets"] as const;
export type StructuredTaskName = (typeof STRUCTURED_TASKS)[number];
export type TaskName = StructuredTaskName | "chat";

/** Rate-limit / concurrency class: chat has its own budget, every other task shares one. */
export type RateClass = "chat" | "task";

export interface TaskConfig {
  /** Name of the exported Cloud Function (also `meta.task` in responses). */
  readonly fn: string;
  readonly model: string;
  readonly effort: Effort;
  /** Effort for the one checks-failed retry (receipts only). */
  readonly retryEffort: Effort | null;
  readonly maxTokens: number;
  readonly rateClass: RateClass;
  /** Paused when global daily spend passes 80% of the budget. */
  readonly pauseAtSoftLimit: boolean;
}

export const DEFAULT_MODEL = "claude-opus-5-5";

export const TASKS: Readonly<Record<TaskName, TaskConfig>> = Object.freeze({
  categorize: {
    fn: "categorizeTransactions",
    model: DEFAULT_MODEL,
    effort: "low",
    retryEffort: null,
    maxTokens: 8192,
    rateClass: "task",
    pauseAtSoftLimit: false,
  },
  quickAdd: {
    fn: "parseQuickAdd",
    model: DEFAULT_MODEL,
    effort: "low",
    retryEffort: null,
    maxTokens: 2048,
    rateClass: "task",
    pauseAtSoftLimit: false,
  },
  receipt: {
    fn: "extractReceipt",
    model: DEFAULT_MODEL,
    effort: "low",
    retryEffort: "medium",
    maxTokens: 8192,
    rateClass: "task",
    pauseAtSoftLimit: false,
  },
  insights: {
    fn: "generateInsights",
    model: DEFAULT_MODEL,
    effort: "medium",
    retryEffort: null,
    maxTokens: 8192,
    rateClass: "task",
    pauseAtSoftLimit: true,
  },
  budgets: {
    fn: "suggestBudgets",
    model: DEFAULT_MODEL,
    effort: "medium",
    retryEffort: null,
    maxTokens: 8192,
    rateClass: "task",
    pauseAtSoftLimit: true,
  },
  chat: {
    fn: "chat",
    model: DEFAULT_MODEL,
    // low for now; medium is to be tested in evals.
    effort: "low",
    retryEffort: null,
    maxTokens: 16384,
    rateClass: "chat",
    pauseAtSoftLimit: false,
  },
});

/** Credits per call (contract §1.3–§1.7, §2). */
export const CREDITS = Object.freeze({
  categorizePerTransactions: 10, // ceil(n / 10)
  quickAdd: 1,
  receipt: 4,
  insights: 5,
  budgets: 5,
  chatUserTextTurn: 2,
  chatToolResultsTurn: 0,
});

/** Multiplier for the single retry after `max_tokens` or an empty parse. */
export const MAX_TOKENS_RETRY_FACTOR = 2;
