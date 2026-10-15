/** generateInsights (contract §1.6): request schema, model-output schema, business rules. */

import { z } from "zod";
import { OUTPUT, PAYLOAD } from "../config/limits.js";
import { decimalString, label, localDate, shortId } from "./common.js";
import { collectNumbers, numbersSupported } from "./numbers.js";

const L = PAYLOAD.insights;
const text = label(L.maxText);

const momRow = z.strictObject({
  ref: shortId,
  category: text,
  current: decimalString,
  previous: decimalString,
  deltaPct: decimalString.nullable(),
});
const anomalyRow = z.strictObject({
  ref: shortId,
  date: localDate,
  merchant: text.nullable(),
  category: text.nullable(),
  amount: decimalString,
  typical: decimalString,
});
const subscriptionRow = z.strictObject({
  ref: shortId,
  merchant: text,
  amount: decimalString,
  cadence: z.string().regex(/^[a-z_]{1,20}$/, "must be a cadence like monthly"),
  status: z.enum(["new", "active", "price_up", "missed"]),
  priceChangePct: decimalString.nullable(),
});
const budgetPaceRow = z.strictObject({
  ref: shortId,
  category: text,
  limit: decimalString,
  spent: decimalString,
  expectedByToday: decimalString,
  status: z.enum(["on_track", "at_risk", "over"]),
});
const goalRow = z.strictObject({
  ref: shortId,
  name: text,
  target: decimalString,
  saved: decimalString,
  pct: decimalString,
  onTrack: z.boolean(),
});

export const insightsPayloadSchema = z
  .strictObject({
    period: z.strictObject({ kind: z.enum(["week", "month"]), start: localDate, end: localDate }),
    stats: z.strictObject({
      monthOverMonth: z.array(momRow).max(L.maxMonthOverMonth),
      anomalies: z.array(anomalyRow).max(L.maxAnomalies),
      subscriptions: z.array(subscriptionRow).max(L.maxSubscriptions),
      budgetPace: z.array(budgetPaceRow).max(L.maxBudgetPace),
      goals: z.array(goalRow).max(L.maxGoals),
    }),
  })
  .superRefine((p, ctx) => {
    if (p.period.start > p.period.end) {
      ctx.addIssue({ code: "custom", message: "start must not be after end", path: ["period", "start"] });
    }
    const seen = new Set<string>();
    for (const [key, rows] of Object.entries(p.stats)) {
      rows.forEach((row: { ref: string }, i: number) => {
        if (seen.has(row.ref)) {
          ctx.addIssue({ code: "custom", message: `duplicate ref "${row.ref}"`, path: ["stats", key, i, "ref"] });
        }
        seen.add(row.ref);
      });
    }
  });
export type InsightsPayload = z.infer<typeof insightsPayloadSchema>;

export const INSIGHT_KINDS = ["spending_trend", "anomaly", "subscription", "budget", "goal", "tip"] as const;
export const SEVERITIES = ["positive", "info", "warning", "critical"] as const;
export const ACTION_TYPES = ["none", "review_transactions", "adjust_budget", "review_subscription", "open_goal"] as const;

export const insightsOutputSchema = z.object({
  insights: z.array(
    z.object({
      kind: z.enum(INSIGHT_KINDS),
      severity: z.enum(SEVERITIES),
      title: z.string(),
      body: z.string(),
      evidenceRefs: z.array(z.string()).describe("refs of the input rows this insight is based on"),
      action: z.object({
        type: z.enum(ACTION_TYPES),
        targetRef: z.string().nullable().describe("ref of the input row the action opens, or null"),
      }),
    }),
  ),
});
export type InsightsOutput = z.infer<typeof insightsOutputSchema>;

export interface Insight {
  kind: (typeof INSIGHT_KINDS)[number];
  severity: (typeof SEVERITIES)[number];
  title: string;
  body: string;
  evidenceRefs: string[];
  action: { type: (typeof ACTION_TYPES)[number]; targetRef: string | null };
}
export interface InsightsResult {
  insights: Insight[];
}

export const insightsResultSchema = z.strictObject({
  insights: z
    .array(
      z.strictObject({
        kind: z.enum(INSIGHT_KINDS),
        severity: z.enum(SEVERITIES),
        title: z.string().min(1).max(OUTPUT.maxInsightTitle),
        body: z.string().min(1).max(OUTPUT.maxInsightBody),
        evidenceRefs: z.array(shortId).min(1),
        action: z.strictObject({ type: z.enum(ACTION_TYPES), targetRef: shortId.nullable() }),
      }),
    )
    .max(OUTPUT.maxInsights),
});

export function inputRefs(payload: InsightsPayload): Set<string> {
  return new Set(Object.values(payload.stats).flatMap((rows: { ref: string }[]) => rows.map((r) => r.ref)));
}

/** Every number present anywhere in the input stats and period (the only numbers text may quote). */
export function allowedNumbers(payload: InsightsPayload): Set<string> {
  const refs = inputRefs(payload);
  // Refs like "mom:c1" are ids, not numbers a sentence may quote.
  const stats = JSON.parse(JSON.stringify(payload.stats), (key, value: unknown) =>
    key === "ref" && typeof value === "string" && refs.has(value) ? undefined : value,
  ) as unknown;
  return collectNumbers([payload.period, stats]);
}

export interface InsightsRuleReport {
  result: InsightsResult;
  dropped: number;
}

/**
 * Business rules: evidence refs must exist (unknown refs removed; none left → dropped), the
 * action target must exist (else the action becomes `none`), any insight quoting a number
 * not in the input is dropped, at most 6 insights are kept in the model's ranked order.
 */
export function applyInsightsRules(output: InsightsOutput, payload: InsightsPayload): InsightsRuleReport {
  const refs = inputRefs(payload);
  const allowed = allowedNumbers(payload);
  const insights: Insight[] = [];
  let dropped = 0;
  for (const raw of output.insights) {
    const title = raw.title.replace(/\s+/g, " ").trim();
    const body = raw.body.replace(/\s+/g, " ").trim();
    const evidenceRefs = [...new Set(raw.evidenceRefs.filter((r) => refs.has(r)))];
    const valid =
      title.length > 0 &&
      body.length > 0 &&
      title.length <= OUTPUT.maxInsightTitle &&
      body.length <= OUTPUT.maxInsightBody &&
      evidenceRefs.length > 0 &&
      numbersSupported(title, allowed) &&
      numbersSupported(body, allowed);
    if (!valid || insights.length >= OUTPUT.maxInsights) {
      dropped += 1;
      continue;
    }
    const targetOk = raw.action.type !== "none" && raw.action.targetRef !== null && refs.has(raw.action.targetRef);
    insights.push({
      kind: raw.kind,
      severity: raw.severity,
      title,
      body,
      evidenceRefs,
      action: targetOk ? { type: raw.action.type, targetRef: raw.action.targetRef } : { type: "none", targetRef: null },
    });
  }
  return { result: { insights }, dropped };
}
