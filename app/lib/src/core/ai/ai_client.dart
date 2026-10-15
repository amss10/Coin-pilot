import 'package:coin_pilot/src/core/ai/ai_dtos.dart';
import 'package:coin_pilot/src/core/ai/chat_models.dart';
import 'package:coin_pilot/src/core/time/local_date.dart';
import 'package:meta/meta.dart';

/// Per-request context sent in the envelope (contract §1.1).
@immutable
final class AiRequestContext {
  const AiRequestContext({
    required this.locale,
    required this.currency,
    required this.timezone,
    required this.today,
  });

  /// BCP-47 tag, e.g. `en-US`.
  final String locale;

  /// Home currency code, e.g. `USD`.
  final String currency;

  /// IANA time zone, e.g. `Africa/Cairo`.
  final String timezone;
  final LocalDate today;
}

/// A successful structured-task response.
@immutable
final class AiResponse<T> {
  const AiResponse({required this.result, required this.credits, required this.meta});

  final T result;
  final AiCredits credits;
  final AiMeta meta;
}

/// Everything the app can ask the AI proxy. Implementations throw `AiFailure`.
abstract interface class AiClient {
  /// True for the offline demo client (the UI shows a notice).
  bool get isDemo;

  Future<AiResponse<CategorizeResult>> categorize(AiRequestContext ctx, CategorizePayload payload);

  Future<AiResponse<QuickAddResult>> parseQuickAdd(AiRequestContext ctx, QuickAddPayload payload);

  Future<AiResponse<ReceiptResult>> extractReceipt(AiRequestContext ctx, ReceiptPayload payload);

  Future<AiResponse<InsightsResult>> generateInsights(
    AiRequestContext ctx,
    InsightsPayload payload,
  );

  Future<AiResponse<BudgetSuggestionsResult>> suggestBudgets(
    AiRequestContext ctx,
    BudgetSuggestionsPayload payload,
  );

  Future<AiUsage> getUsage();

  /// Deletes the caller's server-side usage records and anonymous account.
  Future<void> deleteMyData();

  /// Streams one chat turn. Errors arrive as [ChatErrorEvent], not exceptions.
  Stream<ChatEvent> chat(ChatRequest request);
}
