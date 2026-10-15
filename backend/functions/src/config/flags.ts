/** Environment-dependent switches and fixed request flags. */

export type PrefixMismatchBehavior = "error" | "drop_block";

type Env = Readonly<Record<string, string | undefined>>;

/** Beta headers sent with Claude calls (plan §7.5). */
export const BETA_SERVER_SIDE_FALLBACK = "server-side-fallback-2026-07-01";
export const BETA_THINKING_BINDING_CONTROLS = "thinking-binding-controls-2026-08-01";

/** Let Anthropic route a refused request to its recommended fallback model. */
export const FALLBACKS_MODE = "default";

/** Oldest app version the proxy still serves (overridable from the `config/ai` doc). */
export const MIN_APP_VERSION = "0.1.0";

export function isEmulator(env: Env = process.env): boolean {
  return env["FUNCTIONS_EMULATOR"] === "true";
}

export function isTestEnv(env: Env = process.env): boolean {
  return env["NODE_ENV"] === "test";
}

/** Staging is flagged with COINPILOT_ENV=staging (functions/.env.<project>). */
export function isStaging(env: Env = process.env): boolean {
  return env["COINPILOT_ENV"] === "staging";
}

/**
 * Preserved-thinking prefix check: "error" in the emulator, tests and staging so any history
 * edit fails loudly; "drop_block" in production so a mismatch degrades instead of failing
 * (and is alerted on via the `prefix_binding_mismatch` log).
 */
export function prefixMismatchBehavior(env: Env = process.env): PrefixMismatchBehavior {
  return isEmulator(env) || isTestEnv(env) || isStaging(env) ? "error" : "drop_block";
}
