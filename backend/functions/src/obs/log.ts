/**
 * Metadata-only structured logging. Only whitelisted keys with primitive values can be logged,
 * so request/response bodies, prompts, merchant names or amounts cannot end up in Cloud
 * Logging by accident. Users are identified by an opaque HMAC hash, never by uid.
 */

import { write as firebaseWrite, type LogSeverity } from "firebase-functions/logger";

const LOG_KEYS = [
  "uidHash",
  "fn",
  "task",
  "promptVersion",
  "model",
  "servedBy",
  "effort",
  "attempt",
  "maxTokens",
  "inputTokens",
  "outputTokens",
  "cacheReadTokens",
  "cacheWriteTokens",
  "costMicros",
  "latencyMs",
  "stopReason",
  "refusalCategory",
  "fallback",
  "messageId",
  "requestId",
  "code",
  "reason",
  "httpStatus",
  "errorType",
  "credits",
  "items",
  "dropped",
  "checksPassed",
  "toolRounds",
  "toolChoice",
  "turnKind",
  "transformations",
  "behavior",
  "replay",
  "spentMicros",
  "budgetMicros",
] as const;

export type LogKey = (typeof LOG_KEYS)[number];
export type LogValue = string | number | boolean | null;
export type LogFields = Partial<Record<LogKey, LogValue>>;
export type LogLevel = "debug" | "info" | "warn" | "error";

export interface LogSink {
  write(level: LogLevel, event: string, fields: LogFields): void;
}

const SEVERITY: Record<LogLevel, LogSeverity> = {
  debug: "DEBUG",
  info: "INFO",
  warn: "WARNING",
  error: "ERROR",
};

const ALLOWED = new Set<string>(LOG_KEYS);

/** Drops non-whitelisted keys and non-primitive values (defence in depth for JS callers). */
export function sanitizeFields(fields: LogFields): LogFields {
  const out: LogFields = {};
  for (const [key, value] of Object.entries(fields)) {
    if (!ALLOWED.has(key)) continue;
    if (value === null || ["string", "number", "boolean"].includes(typeof value)) {
      out[key as LogKey] = typeof value === "string" ? value.slice(0, 200) : value;
    }
  }
  return out;
}

const firebaseSink: LogSink = {
  write(level, event, fields) {
    firebaseWrite({ severity: SEVERITY[level], message: event, ...fields });
  },
};

export class Logger {
  constructor(private readonly sink: LogSink = firebaseSink) {}

  debug(event: string, fields: LogFields = {}): void {
    this.sink.write("debug", event, sanitizeFields(fields));
  }
  info(event: string, fields: LogFields = {}): void {
    this.sink.write("info", event, sanitizeFields(fields));
  }
  warn(event: string, fields: LogFields = {}): void {
    this.sink.write("warn", event, sanitizeFields(fields));
  }
  error(event: string, fields: LogFields = {}): void {
    this.sink.write("error", event, sanitizeFields(fields));
  }
}

/** In-memory sink for tests. */
export class MemoryLogSink implements LogSink {
  readonly entries: { level: LogLevel; event: string; fields: LogFields }[] = [];
  write(level: LogLevel, event: string, fields: LogFields): void {
    this.entries.push({ level, event, fields });
  }
}
