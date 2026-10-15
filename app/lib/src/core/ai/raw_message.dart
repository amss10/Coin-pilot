import 'dart:convert';

import 'package:meta/meta.dart';

/// A Claude API message (`{"role": …, "content": …}`) kept as JSON text.
///
/// Claude binds its thinking blocks to the exact conversation history, and
/// the proxy signs that history (ADR 0006). So a message is encoded **once**,
/// when it is received or created, stored as [json], and from then on replayed
/// verbatim — never edited and never re-encoded.
@immutable
final class RawMessage {
  RawMessage._(this.json, this.role, this._decoded);

  /// Wraps stored JSON text without changing it.
  factory RawMessage.fromJson(String json) {
    final decoded = jsonDecode(json);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('A message must be a JSON object');
    }
    final role = decoded['role'];
    if (role is! String) throw const FormatException('A message needs a role');
    return RawMessage._(json, role, decoded);
  }

  /// Encodes a message object received from the proxy. This is the single
  /// encoding step; the resulting [json] is what gets stored and replayed.
  factory RawMessage.fromReceived(Map<String, Object?> message) =>
      RawMessage.fromJson(jsonEncode(message));

  /// A new user question, optionally preceded by a `<context …>` data block.
  factory RawMessage.userTurn({required String question, String? context}) =>
      RawMessage.fromReceived({
        'role': 'user',
        'content': [
          if (context != null) {'type': 'text', 'text': context},
          {'type': 'text', 'text': question},
        ],
      });

  /// One user message carrying the results of every pending tool call.
  factory RawMessage.toolResults(List<ToolResultBlock> results) => RawMessage.fromReceived({
    'role': 'user',
    'content': [
      for (final result in results)
        {
          'type': 'tool_result',
          'tool_use_id': result.toolUseId,
          'content': result.content,
          'is_error': result.isError,
        },
    ],
  });

  /// The exact JSON text to store and replay.
  final String json;
  final String role;
  final Map<String, Object?> _decoded;

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';

  /// Content blocks (a plain-string content becomes one text block).
  List<Map<String, Object?>> get blocks {
    final content = _decoded['content'];
    if (content is String) {
      return [
        {'type': 'text', 'text': content},
      ];
    }
    if (content is List) {
      return [
        for (final block in content)
          if (block is Map<String, Object?>) block,
      ];
    }
    return const [];
  }

  /// Text meant for people: text blocks, minus the app's `<context>` blocks.
  String get visibleText => blocks
      .where((b) => b['type'] == 'text')
      .map((b) => b['text'])
      .whereType<String>()
      .where((text) => !text.trimLeft().startsWith('<context'))
      .join('\n\n')
      .trim();

  bool get hasToolResults => blocks.any((b) => b['type'] == 'tool_result');

  /// Tool calls requested by an assistant message.
  List<PendingToolUse> get toolUses => [
    for (final block in blocks)
      if (block['type'] == 'tool_use')
        PendingToolUse(
          id: block['id']! as String,
          name: block['name']! as String,
          input: (block['input'] as Map?)?.cast<String, Object?>() ?? const {},
        ),
  ];

  @override
  bool operator ==(Object other) => other is RawMessage && other.json == json;

  @override
  int get hashCode => json.hashCode;

  @override
  String toString() => 'RawMessage($role, ${json.length} chars)';
}

/// A tool call the model is waiting on.
@immutable
final class PendingToolUse {
  const PendingToolUse({required this.id, required this.name, required this.input});

  factory PendingToolUse.fromJson(Map<String, Object?> json) => PendingToolUse(
    id: json['id']! as String,
    name: json['name']! as String,
    input: (json['input'] as Map?)?.cast<String, Object?>() ?? const {},
  );

  final String id;
  final String name;
  final Map<String, Object?> input;
}

/// The result of running one tool on the device.
@immutable
final class ToolResultBlock {
  const ToolResultBlock({required this.toolUseId, required this.content, this.isError = false});

  final String toolUseId;

  /// JSON text produced by the tool (≤ 8 KB).
  final String content;
  final bool isError;
}
