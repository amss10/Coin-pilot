/**
 * Claude prices in USD per million tokens (first-party API rates). Fallback models are listed
 * so a server-side fallback is priced at the model that actually ran. Any model missing here
 * is priced at the most expensive known row, so an unexpected model never under-counts spend.
 */

export interface ModelPrice {
  readonly input: number;
  readonly output: number;
  readonly cacheRead: number;
  readonly cacheWrite5m: number;
  readonly cacheWrite1h: number;
}

export const PRICES: Readonly<Record<string, ModelPrice>> = Object.freeze({
  "claude-opus-5-5": { input: 4, output: 20, cacheRead: 0.2, cacheWrite5m: 5, cacheWrite1h: 8 },
  // Expected server-side fallback targets for Opus 5.5 refusals.
  "claude-opus-5": { input: 5, output: 25, cacheRead: 0.5, cacheWrite5m: 6.25, cacheWrite1h: 10 },
  "claude-opus-4-8": { input: 5, output: 25, cacheRead: 0.5, cacheWrite5m: 6.25, cacheWrite1h: 10 },
});

function rowWeight(p: ModelPrice): number {
  return p.input + p.output + p.cacheRead + p.cacheWrite5m + p.cacheWrite1h;
}

/** The most expensive known row (by output price, then the sum of all prices). */
export const MOST_EXPENSIVE_PRICE: ModelPrice = Object.values(PRICES).reduce((max, p) =>
  p.output > max.output || (p.output === max.output && rowWeight(p) > rowWeight(max)) ? p : max,
);

export function priceFor(model: string | null | undefined): ModelPrice {
  if (model && Object.hasOwn(PRICES, model)) {
    return PRICES[model] ?? MOST_EXPENSIVE_PRICE;
  }
  return MOST_EXPENSIVE_PRICE;
}
