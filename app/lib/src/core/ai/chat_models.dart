import 'dart:convert';

import 'package:coin_pilot/src/core/ai/ai_dtos.dart';
import 'package:coin_pilot/src/core/ai/ai_failure.dart';
import 'package:coin_pilot/src/core/ai/raw_message.dart';
import 'package:meta/meta.dart';

/// Tool names the app can execute (contract §2.1). Bump when tools change.
const int kToolsetVersion = 1;

/// One request to the chat endpoint (contract §2).
@immutable
final class ChatRequest {
  const ChatRequest({
    required this.conversationId,
    required this.messages,
    required this.idempotencyKey,
    this.promptVersion,
    this.historyMac,
    this.toolsetVersion = kToolsetVersion,
  });

  final String conversationId;

  /// Committed history (verbatim) followed by exactly one new user message.
  final List<RawMessage> messages;
  final String idempotencyKey;
  final String? promptVersion;
  final String? historyMac;
  final int toolsetVersion;

  /// The JSON body. Stored messages are spliced in as their exact text so they
  /// are never re-encoded on the way out.
  String toJsonBody({required String appVersion}) {
    final buffer = StringBuffer('{')
      ..write('"v":1')
      ..write(',"conversationId":${jsonEncode(conversationId)}')
      ..write(',"promptVersion":${jsonEncode(promptVersion)}')
      ..write(',"toolsetVersion":$toolsetVersion')
      ..write(',"idempotencyKey":${jsonEncode(idempotencyKey)}')
      ..write(',"appVersion":${jsonEncode(appVersion)}')
      ..write(',"historyMac":${jsonEncode(historyMac)}')
      ..write(',"messages":[')
      ..writeAll(messages.map((m) => m.json), ',')
      ..write(']}');
    return buffer.toString();
  }
}

/// Token usage reported in the `final` event.
@immutable
final class ChatUsage {
  const ChatUsage({
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.cacheReadTokens = 0,
    this.cacheWriteTokens = 0,
  });

  factory ChatUsage.fromJson(Map<String, Object?> json) => ChatUsage(
    inputTokens: (json['inputTokens'] as num?)?.toInt() ?? 0,
    outputTokens: (json['outputTokens'] as num?)?.toInt() ?? 0,
    cacheReadTokens: (json['cacheReadTokens'] as num?)?.toInt() ?? 0,
    cacheWriteTokens: (json['cacheWriteTokens'] as num?)?.toInt() ?? 0,
  );

  final int inputTokens;
  final int outputTokens;
  final int cacheReadTokens;
  final int cacheWriteTokens;
}

/// Events streamed by the chat endpoint.
sealed class ChatEvent {
  const ChatEvent();
}

final class ChatMetaEvent extends ChatEvent {
  const ChatMetaEvent({required this.promptVersion, required this.model});

  final String promptVersion;
  final String model;
}

final class ChatTextEvent extends ChatEvent {
  const ChatTextEvent(this.delta);

  final String delta;
}

/// The model started a tool call (status line only; inputs come in [ChatFinalEvent]).
final class ChatToolEvent extends ChatEvent {
  const ChatToolEvent(this.name);

  final String name;
}

/// The turn finished. [append] must be committed verbatim, in order.
final class ChatFinalEvent extends ChatEvent {
  const ChatFinalEvent({
    required this.append,
    required this.stopReason,
    required this.pendingToolUses,
    required this.historyMac,
    this.stopDetails,
    this.usage,
    this.credits,
    this.servedBy,
  });

  factory ChatFinalEvent.fromJson(Map<String, Object?> json) => ChatFinalEvent(
    append: [
      for (final message in (json['append'] as List?) ?? const [])
        RawMessage.fromReceived((message as Map).cast<String, Object?>()),
    ],
    stopReason: json['stopReason'] as String? ?? 'end_turn',
    stopDetails: (json['stopDetails'] as Map?)?.cast<String, Object?>(),
    pendingToolUses: [
      for (final use in (json['pendingToolUses'] as List?) ?? const [])
        PendingToolUse.fromJson((use as Map).cast<String, Object?>()),
    ],
    historyMac: json['historyMac'] as String?,
    usage: json['usage'] is Map
        ? ChatUsage.fromJson((json['usage']! as Map).cast<String, Object?>())
        : null,
    credits: json['credits'] is Map
        ? AiCredits.fromJson((json['credits']! as Map).cast<String, dynamic>())
        : null,
    servedBy: json['servedBy'] as String?,
  );

  final List<RawMessage> append;

  /// `end_turn`, `tool_use`, `max_tokens`, `refusal`, …
  final String stopReason;
  final Map<String, Object?>? stopDetails;
  final List<PendingToolUse> pendingToolUses;
  final String? historyMac;
  final ChatUsage? usage;
  final AiCredits? credits;
  final String? servedBy;

  bool get wantsTools => stopReason == 'tool_use' && pendingToolUses.isNotEmpty;
  bool get isRefusal => stopReason == 'refusal';
}

final class ChatErrorEvent extends ChatEvent {
  const ChatErrorEvent(this.failure);

  final AiFailure failure;
}
