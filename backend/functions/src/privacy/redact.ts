/**
 * Masks identifiers in free text before it is sent to Claude (plan §7.5):
 * - emails, phone numbers and IBANs are removed (replaced by a neutral marker);
 * - card-like numbers and any run of 6+ digits are cut to their last 4 digits.
 *
 * Order matters: structured identifiers are removed first so their digits are not partially
 * masked by the digit-run rule.
 */

export interface RedactOptions {
  /** Digit runs of at least this length are masked (default 6). */
  minDigitRun?: number;
}

const EMAIL_RE = /[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/g;

// Country code + check digits + 11..30 alphanumerics, optionally grouped by 4 with spaces.
const IBAN_RE = /\b[A-Z]{2}\d{2}(?: ?[A-Z0-9]{4}){2,7}(?: ?[A-Z0-9]{1,4})?\b/g;

const PHONE_RES: readonly RegExp[] = [
  // International: +CC then groups.
  /\+\d{1,3}[\s.-]?\(?\d{1,4}\)?(?:[\s.-]?\d{2,4}){2,4}\b/g,
  // Parenthesised area code: (555) 123-4567.
  /\(\d{2,4}\)\s?\d{3,4}[\s.-]?\d{3,4}\b/g,
  // North-American dashed: 555-123-4567.
  /\b\d{3}-\d{3}-\d{4}\b/g,
  // National numbers with a trunk 0 and separators: 010 1234 5678, 020-7946-0958.
  /\b0\d{1,4}[\s.-]\d{3,4}[\s.-]?\d{3,4}\b/g,
];

// Grouped card numbers (4-4-4-4, 4-4-4, Amex 4-6-5).
const CARD_RES: readonly RegExp[] = [/\b\d{4}(?:[ -]\d{4}){2,3}\b/g, /\b\d{4}[ -]\d{6}[ -]\d{5}\b/g];

function lastFour(digits: string): string {
  return `****${digits.slice(-4)}`;
}

function countDigits(s: string): number {
  return s.replace(/\D/g, "").length;
}

export function redact(text: string, options: RedactOptions = {}): string {
  const minRun = Math.max(5, options.minDigitRun ?? 6);
  let out = text.replace(EMAIL_RE, "[email]");
  out = out.replace(IBAN_RE, (m) => (countDigits(m) >= 8 ? "[iban]" : m));
  for (const re of PHONE_RES) {
    out = out.replace(re, (m) => {
      const n = countDigits(m);
      return n >= 7 && n <= 15 ? "[phone]" : m;
    });
  }
  for (const re of CARD_RES) {
    out = out.replace(re, (m) => lastFour(m.replace(/\D/g, "")));
  }
  const runRe = new RegExp(`\\d{${minRun},}`, "g");
  out = out.replace(runRe, (m) => lastFour(m));
  return out;
}

/** Strips control characters, collapses whitespace, then redacts. */
export function cleanText(text: string, options: RedactOptions = {}): string {
  // eslint-disable-next-line no-control-regex
  const noControls = text.replace(/[\u0000-\u001F\u007F]/g, " ");
  return redact(noControls.replace(/\s+/g, " ").trim(), options);
}
