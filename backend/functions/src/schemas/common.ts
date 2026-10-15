/** Shared request primitives (contract §1.2) and Zod → AppError plumbing. */

import { z } from "zod";
import { PAYLOAD } from "../config/limits.js";
import { AppError, type AppErrorIssue } from "../errors.js";
import { isCalendarDate, isMonthString } from "../util/time.js";

/** Short opaque ids sent to the AI (`t1`, `c12`, `a3`, `mom:c1`). */
export const shortId = z
  .string()
  .regex(/^[A-Za-z][A-Za-z0-9_:.-]*$/, "must be a short opaque id")
  .max(PAYLOAD.maxId);

/** Decimal string in the currency's own precision, e.g. "-45.30" or "1200". */
export const decimalString = z
  .string()
  .regex(/^-?\d{1,15}(?:\.\d{1,4})?$/, "must be a decimal string like \"-45.30\"");

export const unsignedDecimalString = z
  .string()
  .regex(/^\d{1,15}(?:\.\d{1,4})?$/, "must be an unsigned decimal string like \"45.30\"");

export const localDate = z.string().refine(isCalendarDate, "must be a YYYY-MM-DD date");
export const monthString = z.string().refine(isMonthString, "must be a YYYY-MM month");
export const currencyCode = z.string().regex(/^[A-Z]{3}$/, "must be an ISO 4217 code");

/** Single-line display text (category, merchant and account names). */
export function label(max: number) {
  return z
    .string()
    .min(1)
    .max(max)
    .refine((s) => !/[\r\n]/.test(s), "must be a single line");
}

export const ACCOUNT_TYPES = ["cash", "checking", "savings", "credit_card", "ewallet", "other"] as const;
export const accountType = z.enum(ACCOUNT_TYPES);

export const categorySchema = z.strictObject({
  id: shortId,
  name: label(PAYLOAD.maxCategoryName),
  kind: z.enum(["expense", "income"]),
  parent: label(PAYLOAD.maxCategoryName).nullable(),
});
export type Category = z.infer<typeof categorySchema>;

export const accountSchema = z.strictObject({
  id: shortId,
  name: label(PAYLOAD.maxAccountName),
  type: accountType,
  currency: currencyCode,
});
export type Account = z.infer<typeof accountSchema>;

function uniqueIds<T extends { id: string }>(items: readonly T[], ctx: z.RefinementCtx): void {
  const seen = new Set<string>();
  items.forEach((item, i) => {
    if (seen.has(item.id)) {
      ctx.addIssue({ code: "custom", message: `duplicate id "${item.id}"`, path: [i, "id"] });
    }
    seen.add(item.id);
  });
}

export const categoriesSchema = z
  .array(categorySchema)
  .max(PAYLOAD.maxCategories)
  .superRefine(uniqueIds);

export const accountsSchema = z.array(accountSchema).max(PAYLOAD.maxAccounts).superRefine(uniqueIds);

export const emptyPayloadSchema = z.strictObject({});

/** Converts Zod issues to the contract's `issues` array (capped, paths joined with "."). */
export function toIssues(error: z.ZodError, prefix: string): AppErrorIssue[] {
  return error.issues.slice(0, 20).map((issue) => ({
    path: [prefix, ...issue.path.map((p) => String(p))].filter(Boolean).join("."),
    message: issue.message,
  }));
}

/** Validates `value` or throws `invalid_input` with issues. Returns Zod's parsed copy. */
export function parseOrThrow<S extends z.ZodType>(schema: S, value: unknown, prefix: string): z.infer<S> {
  const res = schema.safeParse(value);
  if (!res.success) {
    throw new AppError("invalid_input", "The request was not valid.", {
      issues: toIssues(res.error, prefix),
      reason: "schema",
    });
  }
  return res.data;
}

/** UTF-8 size of the JSON encoding of a value. */
export function jsonByteLength(value: unknown): number {
  return Buffer.byteLength(JSON.stringify(value) ?? "", "utf8");
}
