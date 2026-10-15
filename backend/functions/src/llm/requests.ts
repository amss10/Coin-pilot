/**
 * Pure builders for Claude request bodies (plan §7.5). Every call:
 * - takes model / effort / max_tokens from server config (via the prompt registry entry);
 * - sends the frozen system prompt with a cache breakpoint on the last system block;
 * - opts into server-side refusal fallbacks (`fallbacks: "default"`, beta
 *   server-side-fallback-2026-07-01);
 * - sets `metadata.user_id` to an HMAC of the uid (never the uid itself).
 * Chat additionally binds thinking blocks to the conversation (beta
 * thinking-binding-controls-2026-08-01) and uses automatic caching for the growing history.
 */

import { betaZodOutputFormat } from "@anthropic-ai/sdk/helpers/beta/zod";
import type { z } from "zod";
import {
  BETA_SERVER_SIDE_FALLBACK,
  BETA_THINKING_BINDING_CONTROLS,
  FALLBACKS_MODE,
  type PrefixMismatchBehavior,
} from "../config/flags.js";
import type { Effort } from "../config/tasks.js";
import type {
  BetaContentBlockParam,
  BetaMessageParam,
  BetaTool,
  ChatParams,
  SafeOutputFormat,
  StructuredParams,
} from "./port.js";

const formatCache = new WeakMap<z.ZodType, SafeOutputFormat>();

/**
 * Structured-output format built from a static Zod schema with the SDK helper. Its `parse`
 * is wrapped so a truncated or invalid body yields `parsed_output: null` instead of the SDK
 * throwing before `stop_reason` can be checked. (The SDK helper folds `enum` into field
 * descriptions; Zod still enforces enums when the output is parsed.)
 */
export function safeOutputFormat(schema: z.ZodType): SafeOutputFormat {
  const cached = formatCache.get(schema);
  if (cached) return cached;
  const base = betaZodOutputFormat(schema);
  const format: SafeOutputFormat = {
    type: base.type,
    schema: base.schema,
    parse: (content: string): unknown => {
      try {
        return base.parse(content);
      } catch {
        return null;
      }
    },
  };
  formatCache.set(schema, format);
  return format;
}

export interface StructuredRequestInput {
  model: string;
  effort: Effort;
  maxTokens: number;
  system: string;
  content: BetaContentBlockParam[];
  format: SafeOutputFormat;
  userId: string;
}

export function buildStructuredParams(input: StructuredRequestInput): StructuredParams {
  return {
    model: input.model,
    max_tokens: input.maxTokens,
    system: [{ type: "text", text: input.system, cache_control: { type: "ephemeral" } }],
    messages: [{ role: "user", content: input.content }],
    // Opus 5.5 always thinks; adaptive is explicit so a config move to another model keeps it.
    thinking: { type: "adaptive" },
    output_config: { effort: input.effort, format: input.format },
    metadata: { user_id: input.userId },
    betas: [BETA_SERVER_SIDE_FALLBACK],
    fallbacks: FALLBACKS_MODE,
  };
}

export interface ChatRequestInput {
  model: string;
  effort: Effort;
  maxTokens: number;
  system: string;
  tools: readonly BetaTool[];
  messages: BetaMessageParam[];
  toolChoice: "auto" | "none";
  userId: string;
  prefixMismatchBehavior: PrefixMismatchBehavior;
}

export function buildChatParams(input: ChatRequestInput): ChatParams {
  return {
    model: input.model,
    max_tokens: input.maxTokens,
    system: [{ type: "text", text: input.system, cache_control: { type: "ephemeral" } }],
    tools: [...input.tools],
    tool_choice: { type: input.toolChoice },
    messages: input.messages,
    thinking: {
      type: "adaptive",
      block_binding: { prefix_mismatch_behavior: input.prefixMismatchBehavior },
    },
    output_config: { effort: input.effort },
    metadata: { user_id: input.userId },
    // Automatic caching: the breakpoint follows the end of the conversation turn by turn.
    cache_control: { type: "ephemeral" },
    betas: [BETA_SERVER_SIDE_FALLBACK, BETA_THINKING_BINDING_CONTROLS],
    fallbacks: FALLBACKS_MODE,
  };
}
