import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:coin_pilot/src/core/ai/ai_client.dart';
import 'package:coin_pilot/src/core/ai/ai_dtos.dart';
import 'package:coin_pilot/src/core/ai/ai_failure.dart';
import 'package:coin_pilot/src/core/ai/chat_models.dart';
import 'package:coin_pilot/src/core/ai/chat_sse_transport.dart';
import 'package:coin_pilot/src/core/ids/id_generator.dart';

/// [AiClient] backed by the Firebase proxy: callable functions for structured
/// tasks and the SSE endpoint for chat (contract §1–2).
final class FirebaseAiClient implements AiClient {
  FirebaseAiClient({
    required FirebaseFunctions functions,
    required ChatSseTransport chatTransport,
    required IdGenerator ids,
    required String appVersion,
  }) : _functions = functions,
       _chat = chatTransport,
       _ids = ids,
       _appVersion = appVersion;

  final FirebaseFunctions _functions;
  final ChatSseTransport _chat;
  final IdGenerator _ids;
  final String _appVersion;

  static const _timeout = Duration(seconds: 90);

  @override
  bool get isDemo => false;

  @override
  Future<AiResponse<CategorizeResult>> categorize(
    AiRequestContext ctx,
    CategorizePayload payload,
  ) => _task('categorizeTransactions', ctx, payload.toJson(), CategorizeResult.fromJson);

  @override
  Future<AiResponse<QuickAddResult>> parseQuickAdd(
    AiRequestContext ctx,
    QuickAddPayload payload,
  ) => _task('parseQuickAdd', ctx, payload.toJson(), QuickAddResult.fromJson);

  @override
  Future<AiResponse<ReceiptResult>> extractReceipt(
    AiRequestContext ctx,
    ReceiptPayload payload,
  ) => _task('extractReceipt', ctx, payload.toJson(), ReceiptResult.fromJson);

  @override
  Future<AiResponse<InsightsResult>> generateInsights(
    AiRequestContext ctx,
    InsightsPayload payload,
  ) => _task('generateInsights', ctx, payload.toJson(), InsightsResult.fromJson);

  @override
  Future<AiResponse<BudgetSuggestionsResult>> suggestBudgets(
    AiRequestContext ctx,
    BudgetSuggestionsPayload payload,
  ) => _task('suggestBudgets', ctx, payload.toJson(), BudgetSuggestionsResult.fromJson);

  @override
  Future<AiUsage> getUsage() async {
    final data = await _call('getUsage', const <String, Object?>{});
    return AiUsage.fromJson(_map(data['result'] ?? data));
  }

  @override
  Future<void> deleteMyData() => _call('deleteMyData', const <String, Object?>{});

  @override
  Stream<ChatEvent> chat(ChatRequest request) => _chat.send(request);

  Future<AiResponse<T>> _task<T>(
    String function,
    AiRequestContext ctx,
    Map<String, dynamic> payload,
    T Function(Map<String, dynamic>) parse,
  ) async {
    final data = await _call(function, {
      'v': 1,
      'idempotencyKey': _ids.newId(),
      'appVersion': _appVersion,
      'locale': ctx.locale,
      'currency': ctx.currency,
      'timezone': ctx.timezone,
      'today': ctx.today.toIso(),
      'payload': payload,
    });
    return AiResponse(
      result: parse(_map(data['result'])),
      credits: AiCredits.fromJson(_map(data['credits'])),
      meta: AiMeta.fromJson(_map(data['meta'])),
    );
  }

  Future<Map<String, dynamic>> _call(String function, Map<String, Object?> data) async {
    try {
      final callable = _functions.httpsCallable(
        function,
        options: HttpsCallableOptions(timeout: _timeout),
      );
      final result = await callable.call<Object?>(data);
      return _map(result.data);
    } on FirebaseFunctionsException catch (e) {
      if (e.details is Map) {
        throw AiFailure.fromDetails(e.details, fallbackMessage: e.message);
      }
      throw AiFailure(_codeFromCallable(e.code), message: e.message ?? e.code);
    }
  }

  static AiErrorCode _codeFromCallable(String code) => switch (code) {
    'resource-exhausted' => AiErrorCode.rateLimited,
    'unauthenticated' || 'permission-denied' => AiErrorCode.unauthenticated,
    'invalid-argument' => AiErrorCode.invalidInput,
    'unavailable' || 'deadline-exceeded' => AiErrorCode.upstreamUnavailable,
    _ => AiErrorCode.internal,
  };

  /// Callable results arrive as loosely typed maps on some platforms; a JSON
  /// round trip gives plain `Map<String, dynamic>` for the generated parsers.
  static Map<String, dynamic> _map(Object? value) {
    if (value is! Map) {
      throw const AiFailure(AiErrorCode.internal, message: 'Unexpected response shape');
    }
    return (jsonDecode(jsonEncode(value)) as Map).cast<String, dynamic>();
  }
}
