/** categorizeTransactions (contract §1.3): request schema, model-output schema, business rules. */

import { z } from "zod";
import { OUTPUT, PAYLOAD } from "../config/limits.js";
import {
  accountType,
  categoriesSchema,
  decimalString,
  localDate,
  shortId,
} from "./common.js";

const L = PAYLOAD.categorize;

export const categorizePayloadSchema = z
  .strictObject({
    categories: categoriesSchema.refine((c) => c.length > 0, "at least one category is required"),
    corrections: z
      .array(z.strictObject({ text: z.string().min(1).max(L.maxCorrectionText), categoryId: shortId }))
      .max(L.maxCorrections),
    transactions: z
      .array(
        z.strictObject({
          id: shortId,
          text: z.string().min(1).max(L.maxTransactionText),
          amount: decimalString,
          date: localDate,
          accountType,
        }),
      )
      .min(L.minTransactions)
      .max(L.maxTransactions),
  })
  .superRefine((p, ctx) => {
    const categoryIds = new Set(p.categories.map((c) => c.id));
    p.corrections.forEach((c, i) => {
      if (!categoryIds.has(c.categoryId)) {
        ctx.addIssue({
          code: "custom",
          message: "correction references an unknown category",
          path: ["corrections", i, "categoryId"],
        });
      }
    });
    const seen = new Set<string>();
    p.transactions.forEach((t, i) => {
      if (seen.has(t.id)) {
        ctx.addIssue({ code: "custom", message: `duplicate id "${t.id}"`, path: ["transactions", i, "id"] });
      }
      seen.add(t.id);
    });
  });

export type CategorizePayload = z.infer<typeof categorizePayloadSchema>;

/** Static output schema sent to the structured-output API (no per-user enums, no bounds). */
export const categorizeOutputSchema = z.object({
  results: z.array(
    z.object({
      id: z.string().describe("Transaction id exactly as given in the input, e.g. t1."),
      categoryId: z
        .string()
        .nullable()
        .describe("Id of one input category, or null when no category fits."),
      confidence: z.number().describe("Confidence from 0 to 1."),
      merchant: z.string().nullable().describe("Clean, human-readable merchant name, or null."),
      suggestRule: z
        .boolean()
        .describe("True when this merchant should always map to this category."),
    }),
  ),
});
export type CategorizeOutput = z.infer<typeof categorizeOutputSchema>;

export interface CategorizeResultItem {
  id: string;
  categoryId: string | null;
  confidence: number;
  merchant: string | null;
  suggestRule: boolean;
}
export interface CategorizeResult {
  results: CategorizeResultItem[];
}

export const categorizeResultSchema = z.strictObject({
  results: z.array(
    z.strictObject({
      id: shortId,
      categoryId: shortId.nullable(),
      confidence: z.number().min(0).max(1),
      merchant: z.string().min(1).max(OUTPUT.maxMerchant).nullable(),
      suggestRule: z.boolean(),
    }),
  ),
});

export function clampConfidence(value: number): number {
  if (!Number.isFinite(value)) return 0;
  return Math.round(Math.min(1, Math.max(0, value)) * 100) / 100;
}

export function cleanMerchant(value: string | null): string | null {
  if (value === null) return null;
  const trimmed = value.replace(/\s+/g, " ").trim();
  if (trimmed.length === 0 || trimmed.length > OUTPUT.maxMerchant) return null;
  return trimmed;
}

/**
 * Business rules: every input id exactly once (in input order), unknown ids dropped,
 * duplicates resolved first-wins, missing ids filled as uncategorized, unknown category → null.
 */
export function applyCategorizeRules(output: CategorizeOutput, payload: CategorizePayload): CategorizeResult {
  const categoryIds = new Set(payload.categories.map((c) => c.id));
  const byId = new Map<string, CategorizeOutput["results"][number]>();
  for (const r of output.results) {
    if (!byId.has(r.id)) byId.set(r.id, r);
  }
  const results = payload.transactions.map((t): CategorizeResultItem => {
    const r = byId.get(t.id);
    if (!r) {
      return { id: t.id, categoryId: null, confidence: 0, merchant: null, suggestRule: false };
    }
    const known = r.categoryId !== null && categoryIds.has(r.categoryId);
    const confidence = known ? clampConfidence(r.confidence) : 0;
    return {
      id: t.id,
      categoryId: known ? r.categoryId : null,
      confidence,
      merchant: cleanMerchant(r.merchant),
      suggestRule: known && r.suggestRule && confidence >= OUTPUT.minRuleConfidence,
    };
  });
  return { results };
}

export function categorizeCredits(payload: CategorizePayload, perCredit: number): number {
  return Math.ceil(payload.transactions.length / perCredit);
}
