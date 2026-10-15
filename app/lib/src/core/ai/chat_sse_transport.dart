import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:coin_pilot/src/core/ai/ai_failure.dart';
import 'package:coin_pilot/src/core/ai/ai_token_source.dart';
import 'package:coin_pilot/src/core/ai/chat_models.dart';
import 'package:coin_pilot/src/core/ai/sse_parser.dart';
import 'package:http/http.dart' as http;

/// Sends one chat turn to the proxy's SSE endpoint and maps the stream to
/// [ChatEvent]s. Every failure is delivered as a [ChatErrorEvent].
final class ChatSseTransport {
  ChatSseTransport({
    required http.Client client,
    required Uri endpoint,
    required AiTokenSource tokens,
    required String appVersion,
  }) : _client = client,
       _endpoint = endpoint,
       _tokens = tokens,
       _appVersion = appVersion;

  final http.Client _client;
  final Uri _endpoint;
  final AiTokenSource _tokens;
  final String _appVersion;

  Stream<ChatEvent> send(ChatRequest request) async* {
    final http.StreamedResponse response;
    try {
      final appCheck = await _tokens.appCheckToken();
      final httpRequest = http.Request('POST', _endpoint)
        ..headers.addAll({
          'Authorization': 'Bearer ${await _tokens.idToken()}',
          'Content-Type': 'application/json',
          'Accept': 'text/event-stream',
          'X-Firebase-AppCheck': ?appCheck,
        })
        ..body = request.toJsonBody(appVersion: _appVersion);
      response = await _client.send(httpRequest);
    } on SocketException catch (e) {
      yield ChatErrorEvent(AiFailure(AiErrorCode.network, message: e.message));
      return;
    } on http.ClientException catch (e) {
      yield ChatErrorEvent(AiFailure(AiErrorCode.network, message: e.message));
      return;
    }

    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      yield ChatErrorEvent(_failureFromHttp(response.statusCode, body));
      return;
    }

    var finished = false;
    try {
      await for (final event in parseSse(response.stream)) {
        final mapped = _map(event);
        if (mapped == null) continue;
        if (mapped is ChatFinalEvent || mapped is ChatErrorEvent) finished = true;
        yield mapped;
        if (finished) break;
      }
    } on SocketException catch (e) {
      if (!finished) yield ChatErrorEvent(AiFailure(AiErrorCode.network, message: e.message));
      return;
    } on http.ClientException catch (e) {
      if (!finished) yield ChatErrorEvent(AiFailure(AiErrorCode.network, message: e.message));
      return;
    }
    if (!finished) {
      yield const ChatErrorEvent(
        AiFailure(AiErrorCode.network, message: 'Stream ended before the final event'),
      );
    }
  }

  ChatEvent? _map(SseEvent event) {
    final Object? decoded;
    try {
      decoded = jsonDecode(event.data);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;
    final json = decoded.cast<String, Object?>();
    return switch (event.event) {
      'meta' => ChatMetaEvent(
        promptVersion: json['promptVersion'] as String? ?? '',
        model: json['model'] as String? ?? '',
      ),
      'text' => ChatTextEvent(json['delta'] as String? ?? ''),
      'tool' => ChatToolEvent(json['name'] as String? ?? ''),
      'final' => ChatFinalEvent.fromJson(json),
      'error' => ChatErrorEvent(AiFailure.fromDetails(json)),
      _ => null,
    };
  }

  static AiFailure _failureFromHttp(int status, String body) {
    Object? details;
    try {
      final decoded = jsonDecode(body);
      details = decoded is Map && decoded['error'] is Map ? decoded['error'] : decoded;
    } on FormatException {
      details = null;
    }
    if (details is Map && details['code'] != null) {
      return AiFailure.fromDetails(details, fallbackMessage: 'HTTP $status');
    }
    final code = switch (status) {
      401 || 403 => AiErrorCode.unauthenticated,
      409 => AiErrorCode.promptVersionRetired,
      413 || 400 => AiErrorCode.invalidInput,
      429 => AiErrorCode.rateLimited,
      _ => AiErrorCode.upstreamUnavailable,
    };
    return AiFailure(code, message: 'HTTP $status');
  }
}
