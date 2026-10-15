/**
 * RFC 8785 JSON Canonicalization Scheme (JCS).
 *
 * - Object members are sorted by key, comparing UTF-16 code units (JS default string order).
 * - Strings use ECMAScript JSON.stringify escaping (RFC 8785 §3.2.2.2).
 * - Numbers use the ECMAScript Number-to-String algorithm (RFC 8785 §3.2.2.3), which is what
 *   JSON.stringify produces for finite numbers (-0 serializes as 0).
 * - No whitespace. `undefined` members are omitted, like JSON.stringify.
 *
 * The output is identical no matter how the client's JSON library ordered keys, escaped
 * strings or formatted numbers, which is what makes it safe to MAC re-encoded history.
 */

export class CanonicalJsonError extends Error {}

export function canonicalJson(value: unknown): string {
  return serialize(value, new Set());
}

function serialize(value: unknown, seen: Set<object>): string {
  if (value === null) return "null";
  switch (typeof value) {
    case "boolean":
      return value ? "true" : "false";
    case "number":
      if (!Number.isFinite(value)) throw new CanonicalJsonError("non-finite number");
      return JSON.stringify(value);
    case "string":
      return JSON.stringify(value);
    case "object":
      break;
    default:
      throw new CanonicalJsonError(`unsupported type: ${typeof value}`);
  }
  const obj = value as object;
  if (seen.has(obj)) throw new CanonicalJsonError("cyclic structure");
  seen.add(obj);
  let out: string;
  if (Array.isArray(obj)) {
    out = `[${obj.map((v: unknown) => (v === undefined ? "null" : serialize(v, seen))).join(",")}]`;
  } else {
    const record = obj as Record<string, unknown>;
    const keys = Object.keys(record)
      .filter((k) => record[k] !== undefined)
      .sort();
    out = `{${keys.map((k) => `${JSON.stringify(k)}:${serialize(record[k], seen)}`).join(",")}}`;
  }
  seen.delete(obj);
  return out;
}
