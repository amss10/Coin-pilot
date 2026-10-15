/** parseQuickAdd (contract §1.4): request schema, model-output schema, business rules. */

import { z } from "zod";
import { OUTPUT, PAYLOAD } from "../config/limits.js";
import { currencyDecimals, formatToDecimals } from "../util/decimal.js";
import { isCalendarDate } from "../util/time.js";
import { accountsSchema, categoriesSchema } from "./common.js";
import { clampConfidence, cleanMerchant } from "./categorize.js";
import type { RequestContext } from "./envelope.js";

export const quickAddPayloadSchema = z.strictObject({
  text: z
    .string()
    .max(PAYLOAD.quickAdd.maxText)
    .refine((s) => s.trim().length >= PAYLOAD.quickAdd.minText, "text is required"),
  source: z.enum(["typed", "voice"]),
  categories: categoriesSchema,
  accounts: accountsSchema,
});
export type QuickAddPayload = z.infer<typeof quickAddPayloadSchema>;

export const DRAFT_KINDS = ["expense", "income", "transfer"] as const;
export const DATE_TYPES = ["today", "yesterday", "days_ago", "last_weekday", "absolute", "unspecified"] as const;
export const WEEKDAYS = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"] as const;

export const quickAddOutputSchema = z.object({
  draft: z.object({
    kind: z.enum(DRAFT_KINDS),
    amount: z
      .string()
      .nullable()
      .describe("The amount exactly as stated, as a plain positive decimal such as 45 or 12.50; null if not stated."),
    currency: z.string().nullable().describe("ISO 4217 code if the text names a currency, otherwise null."),
    date: z.object({
      type: z.enum(DATE_TYPES),
      daysAgo: z.number().nullable().describe("Whole number of days ago; only for days_ago."),
      weekday: z.enum(WEEKDAYS).nullable().describe("Only for last_weekday."),
      date: z.string().nullable().describe("YYYY-MM-DD; only for absolute."),
    }),
    merchant: z.string().nullable(),
    categoryId: z.string().nullable().describe("Id of one input category, or null."),
    accountId: z.string().nullable().describe("Id of one input account, or null."),
    toAccountId: z.string().nullable().describe("Destination account id; only for transfers."),
    note: z.string().nullable(),
  }),
  confidence: z.number().describe("Confidence from 0 to 1."),
  needsClarification: z.boolean(),
  question: z.string().nullable().describe("One short question when needsClarification is true, else null."),
});
export type QuickAddOutput = z.infer<typeof quickAddOutputSchema>;

export interface QuickAddDate {
  type: (typeof DATE_TYPES)[number];
  daysAgo: number | null;
  weekday: (typeof WEEKDAYS)[number] | null;
  date: string | null;
}

export interface QuickAddResult {
  draft: {
    kind: (typeof DRAFT_KINDS)[number];
    amount: string | null;
    currency: string;
    date: QuickAddDate;
    merchant: string | null;
    categoryId: string | null;
    accountId: string | null;
    toAccountId: string | null;
    note: string | null;
  };
  confidence: number;
  needsClarification: boolean;
  question: string | null;
}

export const quickAddResultSchema = z.strictObject({
  draft: z.strictObject({
    kind: z.enum(DRAFT_KINDS),
    amount: z.string().regex(/^\d+(?:\.\d+)?$/).nullable(),
    currency: z.string().regex(/^[A-Z]{3}$/),
    date: z.strictObject({
      type: z.enum(DATE_TYPES),
      daysAgo: z.number().int().min(1).nullable(),
      weekday: z.enum(WEEKDAYS).nullable(),
      date: z.string().nullable(),
    }),
    merchant: z.string().nullable(),
    categoryId: z.string().nullable(),
    accountId: z.string().nullable(),
    toAccountId: z.string().nullable(),
    note: z.string().max(OUTPUT.maxNote).nullable(),
  }),
  confidence: z.number().min(0).max(1),
  needsClarification: z.boolean(),
  question: z.string().max(OUTPUT.maxQuestion).nullable(),
});

const DEFAULT_AMOUNT_QUESTION = "How much was it?";
const DEFAULT_KIND_QUESTION = "Was this money you spent or money you received?";

/** Normalizes "as stated" amounts to the currency's precision ("45" → "45.00"). Never computes. */
export function normalizeStatedAmount(raw: string | null, currency: string): string | null {
  if (raw === null) return null;
  const compact = raw.trim();
  const formatted = formatToDecimals(compact, currencyDecimals(currency));
  if (formatted === null || /^0+(?:\.0+)?$/.test(formatted)) return null;
  return formatted;
}

function cleanDate(d: QuickAddOutput["draft"]["date"]): QuickAddDate {
  const none: QuickAddDate = { type: "unspecified", daysAgo: null, weekday: null, date: null };
  switch (d.type) {
    case "today":
    case "yesterday":
    case "unspecified":
      return { type: d.type, daysAgo: null, weekday: null, date: null };
    case "days_ago":
      return d.daysAgo !== null && Number.isInteger(d.daysAgo) && d.daysAgo >= 1 && d.daysAgo <= OUTPUT.maxDaysAgo
        ? { type: "days_ago", daysAgo: d.daysAgo, weekday: null, date: null }
        : none;
    case "last_weekday":
      return d.weekday !== null ? { type: "last_weekday", daysAgo: null, weekday: d.weekday, date: null } : none;
    case "absolute":
      return d.date !== null && isCalendarDate(d.date)
        ? { type: "absolute", daysAgo: null, weekday: null, date: d.date }
        : none;
  }
}

function cleanQuestion(q: string | null): string | null {
  if (q === null) return null;
  const t = q.replace(/\s+/g, " ").trim();
  return t.length > 0 && t.length <= OUTPUT.maxQuestion ? t : null;
}

export function applyQuickAddRules(
  output: QuickAddOutput,
  payload: QuickAddPayload,
  ctx: RequestContext,
): QuickAddResult {
  const d = output.draft;
  const categoryIds = new Set(payload.categories.map((c) => c.id));
  const accountIds = new Set(payload.accounts.map((a) => a.id));
  const statedCurrency = d.currency?.trim().toUpperCase() ?? null;
  const currency = statedCurrency !== null && /^[A-Z]{3}$/.test(statedCurrency) ? statedCurrency : ctx.currency;
  const amount = normalizeStatedAmount(d.amount, currency);
  const accountId = d.accountId !== null && accountIds.has(d.accountId) ? d.accountId : null;
  const toAccountId =
    d.kind === "transfer" && d.toAccountId !== null && accountIds.has(d.toAccountId) && d.toAccountId !== accountId
      ? d.toAccountId
      : null;
  const noteText = d.note?.replace(/\s+/g, " ").trim() ?? "";
  const needsClarification = output.needsClarification || amount === null;
  let question: string | null = null;
  if (needsClarification) {
    question =
      cleanQuestion(output.question) ?? (amount === null ? DEFAULT_AMOUNT_QUESTION : DEFAULT_KIND_QUESTION);
  }
  return {
    draft: {
      kind: d.kind,
      amount,
      currency,
      date: cleanDate(d.date),
      merchant: cleanMerchant(d.merchant),
      categoryId: d.categoryId !== null && categoryIds.has(d.categoryId) ? d.categoryId : null,
      accountId,
      toAccountId,
      note: noteText.length > 0 ? noteText.slice(0, OUTPUT.maxNote) : null,
    },
    confidence: clampConfidence(output.confidence),
    needsClarification,
    question,
  };
}
