/**
 * Cost accounting. With server-side fallbacks one API call can run several attempts
 * (a declined attempt plus the fallback model's attempt); `usage.iterations` is then the
 * per-attempt source of truth and the top-level usage covers only the final attempt. Each
 * iteration is priced at the model that ran it.
 */

import { priceFor } from "../config/prices.js";
import type { BetaUsage } from "./port.js";

export interface UsageTotals {
  inputTokens: number;
  outputTokens: number;
  cacheReadTokens: number;
  cacheWriteTokens: number;
}

export interface CallCost {
  /** Cost in micro-USD (USD per MTok equals micro-USD per token), rounded up. */
  micros: number;
  totals: UsageTotals;
  /** True when a fallback model served (or attempted) part of the call. */
  fallback: boolean;
}

interface TokenEntry {
  model: string | null;
  input: number;
  output: number;
  cacheRead: number;
  cacheWrite5m: number;
  cacheWrite1h: number;
}

function n(value: unknown): number {
  return typeof value === "number" && Number.isFinite(value) && value > 0 ? value : 0;
}

function toEntry(raw: Record<string, unknown>, defaultModel: string): TokenEntry {
  const creation = raw["cache_creation"] as Record<string, unknown> | null | undefined;
  const totalWrite = n(raw["cache_creation_input_tokens"]);
  const write1h = creation ? n(creation["ephemeral_1h_input_tokens"]) : 0;
  const write5m = creation ? n(creation["ephemeral_5m_input_tokens"]) : totalWrite;
  // If the TTL breakdown doesn't account for every written token, bill the rest at the 5m rate.
  const unaccounted = Math.max(0, totalWrite - write1h - write5m);
  const model = typeof raw["model"] === "string" ? raw["model"] : null;
  return {
    model: model ?? defaultModel,
    input: n(raw["input_tokens"]),
    output: n(raw["output_tokens"]),
    cacheRead: n(raw["cache_read_input_tokens"]),
    cacheWrite5m: write5m + unaccounted,
    cacheWrite1h: write1h,
  };
}

/**
 * Prices one API response. `servedModel` is `message.model`; `requestedModel` is used for
 * iterations that don't name a model.
 */
export function costOfUsage(usage: BetaUsage, servedModel: string, requestedModel: string): CallCost {
  const iterations = (usage.iterations ?? []) as unknown as Record<string, unknown>[];
  const entries =
    iterations.length > 0
      ? iterations.map((it) => toEntry(it, requestedModel))
      : [toEntry(usage as unknown as Record<string, unknown>, servedModel)];
  let micros = 0;
  const totals: UsageTotals = { inputTokens: 0, outputTokens: 0, cacheReadTokens: 0, cacheWriteTokens: 0 };
  for (const e of entries) {
    const p = priceFor(e.model);
    micros +=
      e.input * p.input +
      e.output * p.output +
      e.cacheRead * p.cacheRead +
      e.cacheWrite5m * p.cacheWrite5m +
      e.cacheWrite1h * p.cacheWrite1h;
    totals.inputTokens += e.input;
    totals.outputTokens += e.output;
    totals.cacheReadTokens += e.cacheRead;
    totals.cacheWriteTokens += e.cacheWrite5m + e.cacheWrite1h;
  }
  const fallback =
    iterations.some((it) => it["type"] === "fallback_message") || servedModel !== requestedModel;
  return { micros: Math.ceil(micros), totals, fallback };
}

/** Accumulates cost across the retries of one request (each retry is a separate API call). */
export class SpendMeter {
  micros = 0;
  readonly totals: UsageTotals = { inputTokens: 0, outputTokens: 0, cacheReadTokens: 0, cacheWriteTokens: 0 };
  calls = 0;

  add(cost: CallCost): void {
    this.micros += cost.micros;
    this.totals.inputTokens += cost.totals.inputTokens;
    this.totals.outputTokens += cost.totals.outputTokens;
    this.totals.cacheReadTokens += cost.totals.cacheReadTokens;
    this.totals.cacheWriteTokens += cost.totals.cacheWriteTokens;
    this.calls += 1;
  }
}
