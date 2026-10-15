/**
 * Exact decimal-string helpers. Money is never a float: amounts travel as decimal strings
 * ("-45.30", "1200") and all arithmetic here is done on scaled BigInts.
 */

const DECIMAL_RE = /^-?\d+(?:\.\d+)?$/;
const UNSIGNED_DECIMAL_RE = /^\d+(?:\.\d+)?$/;

/** ISO 4217 minor units for currencies that do not use 2 decimals. */
const ZERO_DECIMAL = new Set([
  "BIF", "CLP", "DJF", "GNF", "ISK", "JPY", "KMF", "KRW", "PYG", "RWF", "UGX", "UYI", "VND",
  "VUV", "XAF", "XOF", "XPF",
]);
const THREE_DECIMAL = new Set(["BHD", "IQD", "JOD", "KWD", "LYD", "OMR", "TND"]);

export function currencyDecimals(currency: string): number {
  if (ZERO_DECIMAL.has(currency)) return 0;
  if (THREE_DECIMAL.has(currency)) return 3;
  return 2;
}

export function isDecimalString(value: string, opts: { allowNegative?: boolean } = {}): boolean {
  return (opts.allowNegative === false ? UNSIGNED_DECIMAL_RE : DECIMAL_RE).test(value);
}

export function fractionDigits(value: string): number {
  const dot = value.indexOf(".");
  return dot === -1 ? 0 : value.length - dot - 1;
}

/** Parses a decimal string into a BigInt scaled by 10^scale. Returns null when it doesn't fit. */
export function toScaled(value: string, scale: number): bigint | null {
  if (!DECIMAL_RE.test(value)) return null;
  const negative = value.startsWith("-");
  const unsigned = negative ? value.slice(1) : value;
  const [intPart = "0", fracPart = ""] = unsigned.split(".");
  if (fracPart.length > scale) {
    // Only exact when the extra digits are zeros.
    if (!/^0*$/.test(fracPart.slice(scale))) return null;
  }
  const frac = fracPart.slice(0, scale).padEnd(scale, "0");
  const scaled = BigInt(intPart + frac);
  return negative ? -scaled : scaled;
}

/**
 * Formats an unsigned decimal string with exactly `decimals` fraction digits
 * ("45" → "45.00"). Returns null when the value has more significant decimals than allowed.
 */
export function formatToDecimals(value: string, decimals: number): string | null {
  if (!UNSIGNED_DECIMAL_RE.test(value)) return null;
  const scaled = toScaled(value, decimals);
  if (scaled === null) return null;
  const digits = scaled.toString().padStart(decimals + 1, "0");
  if (decimals === 0) return digits;
  return `${digits.slice(0, -decimals)}.${digits.slice(-decimals)}`;
}

/** Exact sum of decimal strings at a common scale; null if any value is not a decimal. */
export function sumScaled(values: readonly string[], scale: number): bigint | null {
  let total = 0n;
  for (const v of values) {
    const s = toScaled(v, scale);
    if (s === null) return null;
    total += s;
  }
  return total;
}

/** Largest number of fraction digits among the values (minimum 0). */
export function commonScale(values: readonly string[]): number {
  return values.reduce((max, v) => Math.max(max, fractionDigits(v)), 0);
}
