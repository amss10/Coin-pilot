/**
 * Prompt registry. Each published version is an immutable entry
 * {id, status, system, tools, model, effort, maxTokens, toolset, retireAt}. Model, effort and
 * max_tokens come from config/tasks.ts; the system prompt and tools are frozen and their
 * bytes are pinned by test/golden/prompt-hashes.json.
 *
 * Lifecycle: active → deprecated (still serves open chats) → retired (chat answers 409
 * `prompt_version_retired`). A deprecated version should keep serving for at least 30 days;
 * set `retireAt` to make retirement automatic.
 */

import { TASKS, type Effort, type StructuredTaskName, type TaskName } from "../config/tasks.js";
import type { BetaTool } from "../llm/port.js";
import { canonicalJson } from "../util/canonicalJson.js";
import { sha256Hex } from "../util/crypto.js";
import { BUDGETS_V1_SYSTEM } from "./budgets/v1.js";
import { CATEGORIZE_V1_SYSTEM } from "./categorize/v1.js";
import { CHAT_V1_SYSTEM, CHAT_V1_TOOLS } from "./chat/v1.js";
import { INSIGHTS_V1_SYSTEM } from "./insights/v1.js";
import { QUICK_ADD_V1_SYSTEM } from "./quick-add/v1.js";
import { RECEIPT_V1_SYSTEM } from "./receipt/v1.js";

export type PromptStatus = "active" | "deprecated" | "retired";

export interface PromptEntry {
  readonly id: string;
  readonly task: TaskName;
  readonly status: PromptStatus;
  readonly system: string;
  readonly tools: readonly BetaTool[];
  readonly model: string;
  readonly effort: Effort;
  readonly maxTokens: number;
  /** Chat only: the app toolset version this prompt's tools require. */
  readonly toolset: number | null;
  /** ISO timestamp after which the version is treated as retired, or null. */
  readonly retireAt: string | null;
}

function deepFreeze<T>(value: T): T {
  if (value !== null && typeof value === "object" && !Object.isFrozen(value)) {
    Object.freeze(value);
    for (const v of Object.values(value)) deepFreeze(v);
  }
  return value;
}

/** Frozen prompt bytes are LF-only regardless of how the source file was checked out. */
function lf(text: string): string {
  return text.replace(/\r\n?/g, "\n");
}

function sortTools(tools: readonly BetaTool[]): BetaTool[] {
  return [...tools].sort((a, b) => (a.name < b.name ? -1 : a.name > b.name ? 1 : 0));
}

interface EntryInput {
  id: string;
  task: TaskName;
  status: PromptStatus;
  system: string;
  tools?: readonly BetaTool[];
  toolset?: number;
  retireAt?: string;
}

export function makeEntry(input: EntryInput): PromptEntry {
  const cfg = TASKS[input.task];
  return deepFreeze({
    id: input.id,
    task: input.task,
    status: input.status,
    system: lf(input.system),
    tools: sortTools(input.tools ?? []),
    model: cfg.model,
    effort: cfg.effort,
    maxTokens: cfg.maxTokens,
    toolset: input.toolset ?? null,
    retireAt: input.retireAt ?? null,
  });
}

export const PROMPTS: readonly PromptEntry[] = Object.freeze([
  makeEntry({ id: "categorize/v1", task: "categorize", status: "active", system: CATEGORIZE_V1_SYSTEM }),
  makeEntry({ id: "quick-add/v1", task: "quickAdd", status: "active", system: QUICK_ADD_V1_SYSTEM }),
  makeEntry({ id: "receipt/v1", task: "receipt", status: "active", system: RECEIPT_V1_SYSTEM }),
  makeEntry({ id: "insights/v1", task: "insights", status: "active", system: INSIGHTS_V1_SYSTEM }),
  makeEntry({ id: "budgets/v1", task: "budgets", status: "active", system: BUDGETS_V1_SYSTEM }),
  makeEntry({
    id: "chat/v1",
    task: "chat",
    status: "active",
    system: CHAT_V1_SYSTEM,
    tools: CHAT_V1_TOOLS,
    toolset: 1,
  }),
]);

/** Version number from an id such as "chat/v12" (0 if malformed). */
export function versionNumber(id: string): number {
  const m = /\/v(\d+)$/.exec(id);
  return m ? Number(m[1]) : 0;
}

export function findPrompt(id: string, entries: readonly PromptEntry[] = PROMPTS): PromptEntry | undefined {
  return entries.find((e) => e.id === id);
}

/** The newest active prompt for a structured task. */
export function activePrompt(task: StructuredTaskName, entries: readonly PromptEntry[] = PROMPTS): PromptEntry {
  const candidates = entries
    .filter((e) => e.task === task && e.status === "active")
    .sort((a, b) => versionNumber(b.id) - versionNumber(a.id));
  const entry = candidates[0];
  if (!entry) throw new Error(`no active prompt for task ${task}`);
  return entry;
}

/** SHA-256 over the canonical JSON of the frozen parts (system + tools). */
export function promptHash(entry: Pick<PromptEntry, "system" | "tools">): string {
  return sha256Hex(canonicalJson({ system: entry.system, tools: entry.tools }));
}
