/** suggestBudgets (contract §1.7): request schema, model-output schema, business rules. */

import { z } from "zod";
import { OUTPUT, PAYLOAD } from "../config/limits.js";
import { label, shortId, unsignedDecimalString } from "./common.js";
import { collectNumbers, numbersSupported } from "./numbers.js";

const L = PAYLOAD.budgets;

export const PREFERENCES = ["save_more", "balanced", "flexible"] as const;
export const CHOICES = ["keep", "tight", "balanced", "relaxed"] as const;
export type BudgetChoice = (typeof CHOICES)[number];

const lineSchema = z.strictObject({
  ref: shortId,
  category: label(L.maxText),
  isFixed: z.boolean(),
  current: unsignedDecimalString.nullable(),
  stats: z.strictObject({
    monthsOfData: z.number().int().min(0).max(600),
    median: unsignedDecimalString,
    mean: unsignedDecimalString,
    min: unsignedDecimalString,
    max: unsignedDecimalString,
    lastMonth: unsignedDecimalString,
  }),
  options: z.strictObject({
    tight: unsignedDecimalString,
    balanced: unsignedDecimalString,
    relaxed: unsignedDecimalString,
  }),
});

export const budgetsPayloadSchema = z
  .strictObject({
    preference: z.enum(PREFERENCES),
    monthlyIncome: unsignedDecimalString.nullable(),
    lines: z.array(lineSchema).min(1).max(L.maxLines),
  })
  .superRefine((p, ctx) => {
    const seen = new Set<string>();
    p.lines.forEach((line, i) => {
      if (seen.has(line.ref)) {
        ctx.addIssue({ code: "custom", message: `duplicate ref "${line.ref}"`, path: ["lines", i, "ref"] });
      }
      seen.add(line.ref);
    });
  });
export type BudgetsPayload = z.infer<typeof budgetsPayloadSchema>;
type BudgetLineInput = BudgetsPayload["lines"][number];

export const budgetsOutputSchema = z.object({
  lines: z.array(
    z.object({
      ref: z.string().describe("ref of an input line"),
      choice: z.enum(CHOICES),
      rationale: z.string().describe("One short sentence in plain language."),
    }),
  ),
  summary: z.string(),
});
export type BudgetsOutput = z.infer<typeof budgetsOutputSchema>;

export interface BudgetLineResult {
  ref: string;
  choice: BudgetChoice;
  amount: string;
  rationale: string;
}
export interface BudgetsResult {
  lines: BudgetLineResult[];
  summary: string;
}

export const budgetsResultSchema = z.strictObject({
  lines: z.array(
    z.strictObject({
      ref: shortId,
      choice: z.enum(CHOICES),
      amount: z.string().regex(/^\d+(?:\.\d+)?$/),
      rationale: z.string().max(OUTPUT.maxRationale),
    }),
  ),
  summary: z.string().max(OUTPUT.maxSummary),
});

export const DEFAULT_RATIONALE = "Suggested from your overall budgeting preference.";
export const DEFAULT_SUMMARY = "These suggestions are based on your recent months of spending.";

const PREFERENCE_DEFAULT: Record<(typeof PREFERENCES)[number], BudgetChoice> = {
  save_more: "tight",
  balanced: "balanced",
  flexible: "relaxed",
};

/** The server, not the model, turns a choice into an amount (copied from the input options). */
export function choiceToAmount(line: BudgetLineInput, choice: BudgetChoice): { choice: BudgetChoice; amount: string } {
  switch (choice) {
    case "keep":
      return line.current !== null ? { choice: "keep", amount: line.current } : { choice: "balanced", amount: line.options.balanced };
    case "tight":
      return { choice, amount: line.options.tight };
    case "balanced":
      return { choice, amount: line.options.balanced };
    case "relaxed":
      return { choice, amount: line.options.relaxed };
  }
}

function cleanSentence(value: string, max: number, allowed: ReadonlySet<string>): string | null {
  const t = value.replace(/\s+/g, " ").trim();
  if (t.length === 0 || t.length > max || !numbersSupported(t, allowed)) return null;
  return t;
}

export function applyBudgetsRules(output: BudgetsOutput, payload: BudgetsPayload): BudgetsResult {
  const allowed = collectNumbers(payload.lines.map((l) => ({ ...l, ref: undefined })));
  if (payload.monthlyIncome !== null) collectNumbers(payload.monthlyIncome, allowed);
  const byRef = new Map<string, BudgetsOutput["lines"][number]>();
  for (const l of output.lines) if (!byRef.has(l.ref)) byRef.set(l.ref, l);
  const lines = payload.lines.map((line): BudgetLineResult => {
    const picked = byRef.get(line.ref);
    const { choice, amount } = choiceToAmount(line, picked?.choice ?? PREFERENCE_DEFAULT[payload.preference]);
    const rationale = picked ? cleanSentence(picked.rationale, OUTPUT.maxRationale, allowed) : null;
    return { ref: line.ref, choice, amount, rationale: rationale ?? DEFAULT_RATIONALE };
  });
  return { lines, summary: cleanSentence(output.summary, OUTPUT.maxSummary, allowed) ?? DEFAULT_SUMMARY };
}
