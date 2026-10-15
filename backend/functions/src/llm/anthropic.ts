/**
 * Anthropic SDK adapter for LlmPort: `client.beta.messages.parse` for structured tasks and
 * `client.beta.messages.stream` for chat, plus mapping of the SDK's typed errors to app codes.
 */

import Anthropic, {
  AnthropicError,
  APIConnectionError,
  APIConnectionTimeoutError,
  APIError,
  APIUserAbortError,
  AuthenticationError,
  BadRequestError,
  InternalServerError,
  NotFoundError,
  PermissionDeniedError,
  RateLimitError,
} from "@anthropic-ai/sdk";
import { SDK } from "../config/runtime.js";
import { AppError } from "../errors.js";
import type { Logger } from "../obs/log.js";
import type {
  BetaMessage,
  CallOptions,
  ChatParams,
  LlmPort,
  StreamSink,
  StructuredParams,
  StructuredResponse,
} from "./port.js";

export interface AnthropicClientOptions {
  apiKey: string;
  /** Test hook: a fetch that replays recorded HTTP responses. */
  fetch?: typeof fetch;
  maxRetries?: number;
}

export function createAnthropicClient(opts: AnthropicClientOptions): Anthropic {
  return new Anthropic({
    apiKey: opts.apiKey,
    maxRetries: opts.maxRetries ?? SDK.maxRetries,
    // The SDK never logs request bodies at warn level.
    logLevel: "warn",
    ...(opts.fetch ? { fetch: opts.fetch } : {}),
  });
}

function retryAfterMs(headers: Headers | undefined): number | undefined {
  if (!headers) return undefined;
  const ms = Number(headers.get("retry-after-ms"));
  if (Number.isFinite(ms) && ms > 0) return Math.ceil(ms);
  const seconds = Number(headers.get("retry-after"));
  if (Number.isFinite(seconds) && seconds > 0) return Math.ceil(seconds * 1000);
  return undefined;
}

const UNAVAILABLE = "The AI service is busy or unavailable. Please try again.";

/**
 * Maps SDK errors to app errors. Transient upstream failures (429, 5xx, overloaded,
 * connection problems) and configuration problems (bad key, no permission, unknown model,
 * billing) become `upstream_unavailable`; configuration problems are also logged loudly.
 * A 413 or a 400 on a request that carries an image becomes `invalid_input`.
 */
export function mapUpstreamError(err: unknown, ctx: { hasImage?: boolean; log?: Logger } = {}): AppError {
  if (err instanceof AppError) return err;
  const configProblem = (reason: string, status: number | undefined, type: string | null) => {
    ctx.log?.error("anthropic_config_error", { reason, httpStatus: status ?? null, errorType: type });
    return new AppError("upstream_unavailable", UNAVAILABLE, { reason, cause: err });
  };
  if (err instanceof APIUserAbortError) {
    return new AppError("upstream_unavailable", UNAVAILABLE, { reason: "aborted", cause: err });
  }
  if (err instanceof APIConnectionTimeoutError) {
    return new AppError("upstream_unavailable", UNAVAILABLE, { reason: "timeout", cause: err });
  }
  if (err instanceof APIConnectionError) {
    return new AppError("upstream_unavailable", UNAVAILABLE, { reason: "connection", cause: err });
  }
  if (err instanceof RateLimitError) {
    const retry = retryAfterMs(err.headers);
    return new AppError("upstream_unavailable", UNAVAILABLE, {
      reason: "rate_limit",
      cause: err,
      ...(retry !== undefined ? { retryAfterMs: retry } : {}),
    });
  }
  if (err instanceof InternalServerError) {
    const reason = err.type === "overloaded_error" || err.status === 529 ? "overloaded" : "server_error";
    const retry = retryAfterMs(err.headers);
    return new AppError("upstream_unavailable", UNAVAILABLE, {
      reason,
      cause: err,
      ...(retry !== undefined ? { retryAfterMs: retry } : {}),
    });
  }
  if (err instanceof AuthenticationError) return configProblem("api_key", err.status, err.type);
  if (err instanceof PermissionDeniedError) return configProblem("permission", err.status, err.type);
  if (err instanceof NotFoundError) return configProblem("model_not_found", err.status, err.type);
  if (err instanceof BadRequestError) {
    if (ctx.hasImage) {
      return new AppError("invalid_input", "The image could not be processed.", {
        reason: "bad_image",
        cause: err,
        issues: [{ path: "payload.image", message: "the image could not be processed" }],
      });
    }
    ctx.log?.error("anthropic_bad_request", { httpStatus: err.status, errorType: err.type });
    return new AppError("internal", "Something went wrong.", { reason: "bad_request", cause: err });
  }
  if (err instanceof APIError) {
    const status = err.status;
    if (status === 413) {
      return new AppError("invalid_input", "The request is too large.", { reason: "too_large", cause: err });
    }
    if (status === 402) return configProblem("billing", status, err.type);
    if (status === 408 || (typeof status === "number" && status >= 500)) {
      return new AppError("upstream_unavailable", UNAVAILABLE, { reason: `http_${status}`, cause: err });
    }
    ctx.log?.error("anthropic_api_error", { httpStatus: status ?? null, errorType: err.type });
    return new AppError("internal", "Something went wrong.", { reason: `http_${status ?? "unknown"}`, cause: err });
  }
  if (err instanceof AnthropicError) {
    ctx.log?.error("anthropic_client_error", { reason: err.name });
    return new AppError("internal", "Something went wrong.", { reason: "sdk", cause: err });
  }
  return new AppError("internal", "Something went wrong.", { reason: "unknown", cause: err });
}

export class AnthropicLlm implements LlmPort {
  constructor(
    private readonly client: Anthropic,
    private readonly log?: Logger,
  ) {}

  async parse(params: StructuredParams, options: CallOptions = {}): Promise<StructuredResponse> {
    try {
      const message = await this.client.beta.messages.parse(params, {
        timeout: SDK.taskTimeoutMs,
        ...(options.signal ? { signal: options.signal } : {}),
      });
      return { message, parsed: message.parsed_output };
    } catch (err) {
      throw mapUpstreamError(err, { hasImage: options.hasImage ?? false, ...(this.log ? { log: this.log } : {}) });
    }
  }

  async stream(params: ChatParams, sink: StreamSink, options: CallOptions = {}): Promise<BetaMessage> {
    const stream = this.client.beta.messages.stream(params, {
      timeout: SDK.chatTimeoutMs,
      ...(options.signal ? { signal: options.signal } : {}),
    });
    stream.on("streamEvent", (event) => {
      if (event.type === "content_block_delta" && event.delta.type === "text_delta") {
        sink.onText(event.delta.text);
      } else if (event.type === "content_block_start" && event.content_block.type === "tool_use") {
        sink.onToolUse(event.content_block.name);
      }
    });
    try {
      return await stream.finalMessage();
    } catch (err) {
      throw mapUpstreamError(err, this.log ? { log: this.log } : {});
    }
  }
}
