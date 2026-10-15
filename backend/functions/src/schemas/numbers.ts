/**
 * "The AI never invents numbers": helpers that check every number quoted in model-written text
 * already appears in the input. Numbers are compared by value, so "320", "320.00" and
 * "1,200.50" vs "1200.50" match, and signs are ignored ("spent 45.30" vs "-45.30").
 */

const NUMBER_RE = /\d+(?:,\d{3})*(?:\.\d+)?/g;

/** Canonical absolute form of a numeric token: no grouping, no trailing zeros. */
export function canonicalNumber(token: string): string {
  let s = token.replace(/,/g, "");
  if (s.includes(".")) s = s.replace(/0+$/, "").replace(/\.$/, "");
  s = s.replace(/^0+(?=\d)/, "");
  return s === "" ? "0" : s;
}

export function extractNumbers(text: string): string[] {
  return (text.match(NUMBER_RE) ?? []).map(canonicalNumber);
}

/** Collects every number appearing in any string or number inside `value`. */
export function collectNumbers(value: unknown, into: Set<string> = new Set()): Set<string> {
  if (typeof value === "string") {
    for (const n of extractNumbers(value)) into.add(n);
  } else if (typeof value === "number" && Number.isFinite(value)) {
    for (const n of extractNumbers(String(Math.abs(value)))) into.add(n);
  } else if (Array.isArray(value)) {
    for (const v of value) collectNumbers(v, into);
  } else if (value !== null && typeof value === "object") {
    for (const v of Object.values(value)) collectNumbers(v, into);
  }
  return into;
}

/** Numbers quoted in `text` that are not in `allowed`. */
export function unsupportedNumbers(text: string, allowed: ReadonlySet<string>): string[] {
  return extractNumbers(text).filter((n) => !allowed.has(n));
}

export function numbersSupported(text: string, allowed: ReadonlySet<string>): boolean {
  return unsupportedNumbers(text, allowed).length === 0;
}
