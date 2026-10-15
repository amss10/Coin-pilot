/**
 * LlmPort: the only seam between the proxy and Claude. Production uses the Anthropic SDK
 * adapter (llm/anthropic.ts); unit tests inject a fake that replays recorded responses.
 *
 * Request bodies are built by pure functions (llm/requests.ts) using the SDK's own beta param
 * types, so tests can assert exactly what would be sent.
 */

import type { AutoParseableBetaOutputFormat } from "@anthropic-ai/sdk/lib/beta-parser";
import type {
  BetaMessage,
  BetaMessageStreamParams,
  BetaOutputConfig,
  MessageCreateParamsNonStreaming,
} from "@anthropic-ai/sdk/resources/beta/messages/messages";

export type {
  BetaContentBlock,
  BetaContentBlockParam,
  BetaMessage,
  BetaMessageParam,
  BetaTool,
  BetaUsage,
} from "@anthropic-ai/sdk/resources/beta/messages/messages";

/**
 * A structured-output format whose `parse` never throws: it returns null when the text is
 * not valid JSON for the schema (e.g. cut off at max_tokens), so the caller can inspect
 * `stop_reason` before reading any output.
 */
export type SafeOutputFormat = AutoParseableBetaOutputFormat<unknown>;

/** Non-streaming structured request (`client.beta.messages.parse`). */
export type StructuredParams = Omit<MessageCreateParamsNonStreaming, "output_config"> & {
  output_config: Omit<BetaOutputConfig, "format"> & { format: SafeOutputFormat };
};

/** Streaming chat request (`client.beta.messages.stream`). */
export type ChatParams = BetaMessageStreamParams;

export interface CallOptions {
  signal?: AbortSignal;
  /** The request carries an image: a 400 from the API is then reported as invalid input. */
  hasImage?: boolean;
}

export interface StructuredResponse {
  message: BetaMessage;
  /** `parsed_output` from the SDK (null when absent or unparseable). Re-validated by callers. */
  parsed: unknown;
}

export interface StreamSink {
  onText(delta: string): void;
  onToolUse(name: string): void;
}

export interface LlmPort {
  parse(params: StructuredParams, options?: CallOptions): Promise<StructuredResponse>;
  stream(params: ChatParams, sink: StreamSink, options?: CallOptions): Promise<BetaMessage>;
}
