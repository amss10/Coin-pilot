/** extractReceipt (contract §1.5): request schema, model-output schema, business rules, checks. */

import { z } from "zod";
import { OUTPUT, PAYLOAD } from "../config/limits.js";
import { AppError } from "../errors.js";
import { cleanText } from "../privacy/redact.js";
import { commonScale, sumScaled, toScaled } from "../util/decimal.js";
import { base64DecodedLength, readJpegInfo } from "../util/jpeg.js";
import { isCalendarDate } from "../util/time.js";
import { categoriesSchema } from "./common.js";
import { cleanMerchant } from "./categorize.js";

export const receiptPayloadSchema = z.strictObject({
  image: z.strictObject({
    mediaType: z.literal("image/jpeg"),
    base64: z
      .string()
      .min(16)
      .regex(/^[A-Za-z0-9+/]+={0,2}$/, "must be plain base64 without a data: prefix")
      .refine((s) => s.length % 4 === 0, "base64 length must be a multiple of 4"),
  }),
  categories: categoriesSchema,
});
export type ReceiptPayload = z.infer<typeof receiptPayloadSchema>;

function imageIssue(message: string): AppError {
  return new AppError("invalid_input", "The receipt image was not accepted.", {
    issues: [{ path: "payload.image.base64", message }],
    reason: "image",
  });
}

/**
 * Server-side image checks: JPEG only, ≤ 2 MB decoded, long edge ≤ 2576 px (read from the
 * JPEG header), and EXIF must already be stripped (no location data leaves the phone).
 */
export function validateReceiptImage(base64: string): { width: number; height: number; bytes: number } {
  const bytes = base64DecodedLength(base64);
  if (bytes > PAYLOAD.receipt.maxImageBytes) {
    throw imageIssue(`image must be at most ${PAYLOAD.receipt.maxImageBytes} bytes`);
  }
  const info = readJpegInfo(Buffer.from(base64, "base64"));
  if (info === null) throw imageIssue("image is not a readable JPEG");
  if (Math.max(info.width, info.height) > PAYLOAD.receipt.maxLongEdgePx) {
    throw imageIssue(`image long edge must be at most ${PAYLOAD.receipt.maxLongEdgePx} px`);
  }
  if (info.hasExif) throw imageIssue("image EXIF metadata must be removed before upload");
  return { width: info.width, height: info.height, bytes };
}

export const LEGIBILITY = ["good", "partial", "poor"] as const;

export const receiptOutputSchema = z.object({
  isReceipt: z.boolean().describe("False when the image is not a purchase receipt or invoice."),
  legibility: z.enum(LEGIBILITY),
  merchant: z.string().nullable(),
  date: z.string().nullable().describe("YYYY-MM-DD as printed, or null."),
  time: z.string().nullable().describe("HH:MM 24-hour, or null."),
  currency: z.string().nullable().describe("ISO 4217 code, or null if not determinable."),
  subtotal: z.string().nullable().describe("Plain decimal as printed, e.g. 100.00, or null."),
  tax: z.string().nullable().describe("Tax added on top of the subtotal, or null."),
  tip: z.string().nullable(),
  total: z.string().nullable(),
  lineItems: z.array(
    z.object({
      description: z.string(),
      quantity: z.string().nullable().describe("Plain decimal quantity, or null."),
      amount: z.string().describe("Line amount as printed; discounts are negative."),
    }),
  ),
  suggestedCategoryId: z.string().nullable().describe("Id of one input category, or null."),
});
export type ReceiptOutput = z.infer<typeof receiptOutputSchema>;

export interface ReceiptChecks {
  itemsMatchSubtotal: boolean | null;
  totalsConsistent: boolean | null;
}

export interface ReceiptLineItem {
  description: string;
  quantity: string | null;
  amount: string;
}

export interface ReceiptResult {
  isReceipt: boolean;
  legibility: (typeof LEGIBILITY)[number];
  merchant: string | null;
  date: string | null;
  time: string | null;
  currency: string | null;
  subtotal: string | null;
  tax: string | null;
  tip: string | null;
  total: string | null;
  lineItems: ReceiptLineItem[];
  suggestedCategoryId: string | null;
  checks: ReceiptChecks;
}

const decimalOrNull = z.string().regex(/^-?\d+(?:\.\d+)?$/).nullable();
export const receiptResultSchema = z.strictObject({
  isReceipt: z.boolean(),
  legibility: z.enum(LEGIBILITY),
  merchant: z.string().nullable(),
  date: z.string().nullable(),
  time: z.string().nullable(),
  currency: z.string().regex(/^[A-Z]{3}$/).nullable(),
  subtotal: decimalOrNull,
  tax: decimalOrNull,
  tip: decimalOrNull,
  total: decimalOrNull,
  lineItems: z.array(
    z.strictObject({
      description: z.string().max(OUTPUT.maxLineDescription),
      quantity: z.string().regex(/^\d+(?:\.\d+)?$/).nullable(),
      amount: z.string().regex(/^-?\d+(?:\.\d+)?$/),
    }),
  ),
  suggestedCategoryId: z.string().nullable(),
  checks: z.strictObject({ itemsMatchSubtotal: z.boolean().nullable(), totalsConsistent: z.boolean().nullable() }),
});

const SIGNED_DECIMAL = /^-?\d+(?:\.\d+)?$/;
const UNSIGNED_DECIMAL = /^\d+(?:\.\d+)?$/;

function decimalField(value: string | null, signed = true): string | null {
  if (value === null) return null;
  const v = value.trim();
  return (signed ? SIGNED_DECIMAL : UNSIGNED_DECIMAL).test(v) ? v : null;
}

/** Exact arithmetic checks on the transcribed numbers (null when they can't be computed). */
export function computeReceiptChecks(r: Pick<ReceiptResult, "subtotal" | "tax" | "tip" | "total" | "lineItems">): ReceiptChecks {
  let itemsMatchSubtotal: boolean | null = null;
  if (r.subtotal !== null && r.lineItems.length > 0) {
    const values = [r.subtotal, ...r.lineItems.map((l) => l.amount)];
    const scale = commonScale(values);
    const sum = sumScaled(
      r.lineItems.map((l) => l.amount),
      scale,
    );
    const subtotal = toScaled(r.subtotal, scale);
    itemsMatchSubtotal = sum !== null && subtotal !== null ? sum === subtotal : null;
  }
  let totalsConsistent: boolean | null = null;
  if (r.subtotal !== null && r.total !== null) {
    const parts = [r.subtotal, r.tax ?? "0", r.tip ?? "0"];
    const scale = commonScale([...parts, r.total]);
    const sum = sumScaled(parts, scale);
    const total = toScaled(r.total, scale);
    totalsConsistent = sum !== null && total !== null ? sum === total : null;
  }
  return { itemsMatchSubtotal, totalsConsistent };
}

export function receiptChecksFailed(checks: ReceiptChecks): boolean {
  return checks.itemsMatchSubtotal === false || checks.totalsConsistent === false;
}

/** +1 per passing check, −1 per failing check: used to keep the better of two attempts. */
export function receiptCheckScore(checks: ReceiptChecks): number {
  const score = (v: boolean | null) => (v === true ? 1 : v === false ? -1 : 0);
  return score(checks.itemsMatchSubtotal) + score(checks.totalsConsistent);
}

export function applyReceiptRules(output: ReceiptOutput, payload: ReceiptPayload): ReceiptResult {
  if (!output.isReceipt) {
    return {
      isReceipt: false,
      legibility: output.legibility,
      merchant: null,
      date: null,
      time: null,
      currency: null,
      subtotal: null,
      tax: null,
      tip: null,
      total: null,
      lineItems: [],
      suggestedCategoryId: null,
      checks: { itemsMatchSubtotal: null, totalsConsistent: null },
    };
  }
  const categoryIds = new Set(payload.categories.map((c) => c.id));
  const lineItems: ReceiptLineItem[] = [];
  for (const item of output.lineItems) {
    if (lineItems.length >= OUTPUT.maxReceiptLineItems) break;
    const amount = decimalField(item.amount);
    if (amount === null) continue;
    // Card / loyalty numbers that slipped into a description are masked here too.
    const description = cleanText(item.description).slice(0, OUTPUT.maxLineDescription);
    lineItems.push({ description, quantity: decimalField(item.quantity, false), amount });
  }
  const currency = output.currency?.trim().toUpperCase() ?? null;
  const merchant = output.merchant === null ? null : cleanMerchant(cleanText(output.merchant));
  const base = {
    subtotal: decimalField(output.subtotal),
    tax: decimalField(output.tax),
    tip: decimalField(output.tip),
    total: decimalField(output.total),
    lineItems,
  };
  return {
    isReceipt: true,
    legibility: output.legibility,
    merchant,
    date: output.date !== null && isCalendarDate(output.date.trim()) ? output.date.trim() : null,
    time: output.time !== null && /^([01]\d|2[0-3]):[0-5]\d$/.test(output.time.trim()) ? output.time.trim() : null,
    currency: currency !== null && /^[A-Z]{3}$/.test(currency) ? currency : null,
    ...base,
    suggestedCategoryId:
      output.suggestedCategoryId !== null && categoryIds.has(output.suggestedCategoryId)
        ? output.suggestedCategoryId
        : null,
    checks: computeReceiptChecks(base),
  };
}
