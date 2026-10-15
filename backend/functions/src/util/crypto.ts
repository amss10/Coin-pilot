import { createHash, createHmac, timingSafeEqual } from "node:crypto";

export function sha256Hex(data: string | Buffer): string {
  return createHash("sha256").update(data).digest("hex");
}

export function hmacSha256(key: string | Buffer, data: string): Buffer {
  return createHmac("sha256", key).update(data, "utf8").digest();
}

export function base64url(buf: Buffer): string {
  return buf.toString("base64url");
}

/** Constant-time comparison of two strings (false when lengths differ). */
export function safeEqual(a: string, b: string): boolean {
  const ab = Buffer.from(a, "utf8");
  const bb = Buffer.from(b, "utf8");
  if (ab.length !== bb.length) return false;
  return timingSafeEqual(ab, bb);
}

/**
 * Derives a purpose-specific subkey from the HMAC_KEY secret so the history MAC and the
 * opaque user id never share key material.
 */
export function deriveKey(masterKey: string, purpose: string): Buffer {
  return hmacSha256(masterKey, `coin-pilot/${purpose}/v1`);
}

/** Opaque, stable per-user id: sent as `metadata.user_id` and used as the log hash. */
export function opaqueUserId(masterKey: string, uid: string): string {
  return base64url(hmacSha256(deriveKey(masterKey, "user-id"), uid)).slice(0, 32);
}
