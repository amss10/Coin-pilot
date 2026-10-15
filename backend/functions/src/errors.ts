/**
 * Application error model. Every failure the app can act on is an AppError with one of the
 * contract's app codes (docs/ai-contract.md §1.1 and §2). Transport adapters (http/errors.ts)
 * turn these into HttpsErrors (callables) or HTTP statuses / SSE `error` events (chat).
 */

export const APP_ERROR_CODES = [
  "quota_exceeded",
  "rate_limited",
  "refusal",
  "invalid_input",
  "upstream_unavailable",
  "upgrade_required",
  "unauthenticated",
  "internal",
  "prompt_version_retired",
  "conversation_too_long",
] as const;

export type AppErrorCode = (typeof APP_ERROR_CODES)[number];

export interface AppErrorIssue {
  path: string;
  message: string;
}

export interface AppErrorOptions {
  retryAfterMs?: number;
  resetsAt?: string;
  issues?: AppErrorIssue[];
  /** Refusal category from `stop_details`, when the code is `refusal`. Logged, never shown. */
  refusalCategory?: string | null;
  /** Internal reason for logs (never sent to the client). */
  reason?: string;
  cause?: unknown;
}

export class AppError extends Error {
  readonly code: AppErrorCode;
  readonly retryAfterMs: number | undefined;
  readonly resetsAt: string | undefined;
  readonly issues: AppErrorIssue[] | undefined;
  readonly refusalCategory: string | null | undefined;
  readonly reason: string | undefined;

  constructor(code: AppErrorCode, message: string, options: AppErrorOptions = {}) {
    super(message, options.cause === undefined ? undefined : { cause: options.cause });
    this.name = "AppError";
    this.code = code;
    this.retryAfterMs = options.retryAfterMs;
    this.resetsAt = options.resetsAt;
    this.issues = options.issues;
    this.refusalCategory = options.refusalCategory;
    this.reason = options.reason;
  }
}

export function isAppError(err: unknown): err is AppError {
  return err instanceof AppError;
}

/** Wraps anything thrown into an AppError (unknown failures become `internal`). */
export function toAppError(err: unknown): AppError {
  if (err instanceof AppError) return err;
  return new AppError("internal", "Something went wrong.", { cause: err, reason: "unhandled" });
}

/** Messages shown to users are neutral and never echo request content. */
export const DEFAULT_MESSAGES: Record<AppErrorCode, string> = {
  quota_exceeded: "AI credits are used up for now.",
  rate_limited: "Too many requests. Please wait a moment.",
  refusal: "The AI could not help with this request.",
  invalid_input: "The request was not valid.",
  upstream_unavailable: "The AI service is busy or unavailable. Please try again.",
  upgrade_required: "Please update the app to keep using AI features.",
  unauthenticated: "Sign-in is required.",
  internal: "Something went wrong.",
  prompt_version_retired: "This chat can no longer be continued. Please start a new chat.",
  conversation_too_long: "This chat is too long. Please start a new chat.",
};
