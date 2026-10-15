/**
 * Request/response envelope for the callable functions (contract §1.1).
 * Request: {v, idempotencyKey, appVersion, locale, currency, timezone, today, payload}.
 * Response: {result, credits{charged, remaining, resetsAt}, meta{task, promptVersion, model}}.
 */

import { z } from "zod";
import { compareVersions, isValidTimeZone } from "../util/time.js";
import { AppError } from "../errors.js";
import { currencyCode, localDate } from "./common.js";

export const idempotencyKey = z
  .string()
  .regex(/^[A-Za-z0-9_-]{8,64}$/, "must be 8-64 characters of [A-Za-z0-9_-]");

export const appVersion = z
  .string()
  .regex(/^\d{1,4}\.\d{1,4}\.\d{1,4}(?:\+\d{1,9})?$/, "must look like 1.2.3+45");

export const envelopeSchema = z.strictObject({
  v: z.literal(1),
  idempotencyKey,
  appVersion,
  locale: z.string().regex(/^[A-Za-z]{2,3}(?:[-_][A-Za-z0-9]{2,8}){0,3}$/, "must be a BCP 47 tag"),
  currency: currencyCode,
  timezone: z.string().max(64).refine(isValidTimeZone, "must be an IANA time zone"),
  today: localDate,
  payload: z.unknown(),
});

export type Envelope = z.infer<typeof envelopeSchema>;

/** The envelope fields the prompts may use, without the payload. */
export type RequestContext = Omit<Envelope, "payload">;

export interface CreditsInfo {
  charged: number;
  remaining: number;
  resetsAt: string;
}

export interface ResponseMeta {
  task: string;
  promptVersion: string | null;
  model: string | null;
}

export interface CallableResponse<R> {
  result: R;
  credits: CreditsInfo;
  meta: ResponseMeta;
}

/** Throws `upgrade_required` when the app is older than the minimum supported version. */
export function assertAppVersion(version: string, minVersion: string): void {
  if (compareVersions(version, minVersion) < 0) {
    throw new AppError("upgrade_required", "Please update the app to keep using AI features.", {
      reason: "app_version",
    });
  }
}
