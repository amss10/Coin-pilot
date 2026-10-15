// Wire types for the AI proxy. They mirror docs/ai-contract.md exactly;
// change the contract first, then these classes and the backend schemas.
import 'package:freezed_annotation/freezed_annotation.dart';

part 'ai_dtos.freezed.dart';
part 'ai_dtos.g.dart';

// ---------------------------------------------------------------- shared --

@freezed
abstract class AiCategoryRef with _$AiCategoryRef {
  const factory AiCategoryRef({
    required String id,
    required String name,

    /// `expense` or `income`.
    required String kind,
    String? parent,
  }) = _AiCategoryRef;

  factory AiCategoryRef.fromJson(Map<String, dynamic> json) => _$AiCategoryRefFromJson(json);
}

@freezed
abstract class AiAccountRef with _$AiAccountRef {
  const factory AiAccountRef({
    required String id,
    required String name,

    /// `cash | checking | savings | credit_card | ewallet | other`.
    required String type,
    required String currency,
  }) = _AiAccountRef;

  factory AiAccountRef.fromJson(Map<String, dynamic> json) => _$AiAccountRefFromJson(json);
}

@freezed
abstract class AiCredits with _$AiCredits {
  const factory AiCredits({
    required int charged,
    required int remaining,
    required String resetsAt,
  }) = _AiCredits;

  factory AiCredits.fromJson(Map<String, dynamic> json) => _$AiCreditsFromJson(json);
}

@freezed
abstract class AiMeta with _$AiMeta {
  const factory AiMeta({
    required String task,
    required String promptVersion,
    required String model,
  }) = _AiMeta;

  factory AiMeta.fromJson(Map<String, dynamic> json) => _$AiMetaFromJson(json);
}

@freezed
abstract class AiUsage with _$AiUsage {
  const factory AiUsage({
    required int creditsUsed,
    required int creditsLimit,
    required int remaining,
    required String resetsAt,
  }) = _AiUsage;

  factory AiUsage.fromJson(Map<String, dynamic> json) => _$AiUsageFromJson(json);
}

// ------------------------------------------------------------ categorize --

@freezed
abstract class CategorizeCorrection with _$CategorizeCorrection {
  const factory CategorizeCorrection({required String text, required String categoryId}) =
      _CategorizeCorrection;

  factory CategorizeCorrection.fromJson(Map<String, dynamic> json) =>
      _$CategorizeCorrectionFromJson(json);
}

@freezed
abstract class CategorizeTransaction with _$CategorizeTransaction {
  const factory CategorizeTransaction({
    required String id,
    required String text,
    required String amount,
    required String date,
    required String accountType,
  }) = _CategorizeTransaction;

  factory CategorizeTransaction.fromJson(Map<String, dynamic> json) =>
      _$CategorizeTransactionFromJson(json);
}

@freezed
abstract class CategorizePayload with _$CategorizePayload {
  const factory CategorizePayload({
    required List<AiCategoryRef> categories,
    required List<CategorizeCorrection> corrections,
    required List<CategorizeTransaction> transactions,
  }) = _CategorizePayload;

  factory CategorizePayload.fromJson(Map<String, dynamic> json) =>
      _$CategorizePayloadFromJson(json);
}

@freezed
abstract class CategorizeResultItem with _$CategorizeResultItem {
  const factory CategorizeResultItem({
    required String id,
    required String? categoryId,
    required double confidence,
    required String? merchant,
    required bool suggestRule,
  }) = _CategorizeResultItem;

  factory CategorizeResultItem.fromJson(Map<String, dynamic> json) =>
      _$CategorizeResultItemFromJson(json);
}

@freezed
abstract class CategorizeResult with _$CategorizeResult {
  const factory CategorizeResult({required List<CategorizeResultItem> results}) =
      _CategorizeResult;

  factory CategorizeResult.fromJson(Map<String, dynamic> json) => _$CategorizeResultFromJson(json);
}

// ------------------------------------------------------------- quick add --

@freezed
abstract class QuickAddPayload with _$QuickAddPayload {
  const factory QuickAddPayload({
    required String text,

    /// `typed` or `voice`.
    required String source,
    required List<AiCategoryRef> categories,
    required List<AiAccountRef> accounts,
  }) = _QuickAddPayload;

  factory QuickAddPayload.fromJson(Map<String, dynamic> json) => _$QuickAddPayloadFromJson(json);
}

/// Relative date as stated by the user; the app resolves it (see
/// `DateExprResolver`).
@freezed
abstract class QuickAddDate with _$QuickAddDate {
  const factory QuickAddDate({
    /// `today | yesterday | days_ago | last_weekday | absolute | unspecified`.
    required String type,
    int? daysAgo,
    String? weekday,
    String? date,
  }) = _QuickAddDate;

  factory QuickAddDate.fromJson(Map<String, dynamic> json) => _$QuickAddDateFromJson(json);
}

@freezed
abstract class QuickAddDraftDto with _$QuickAddDraftDto {
  const factory QuickAddDraftDto({
    /// `expense | income | transfer`.
    required String kind,
    required String? amount,
    required String? currency,
    required QuickAddDate date,
    required String? merchant,
    required String? categoryId,
    required String? accountId,
    required String? toAccountId,
    required String? note,
  }) = _QuickAddDraftDto;

  factory QuickAddDraftDto.fromJson(Map<String, dynamic> json) =>
      _$QuickAddDraftDtoFromJson(json);
}

@freezed
abstract class QuickAddResult with _$QuickAddResult {
  const factory QuickAddResult({
    required QuickAddDraftDto draft,
    required double confidence,
    required bool needsClarification,
    required String? question,
  }) = _QuickAddResult;

  factory QuickAddResult.fromJson(Map<String, dynamic> json) => _$QuickAddResultFromJson(json);
}

// --------------------------------------------------------------- receipt --

@freezed
abstract class ReceiptImage with _$ReceiptImage {
  const factory ReceiptImage({required String mediaType, required String base64}) = _ReceiptImage;

  factory ReceiptImage.fromJson(Map<String, dynamic> json) => _$ReceiptImageFromJson(json);
}

@freezed
abstract class ReceiptPayload with _$ReceiptPayload {
  const factory ReceiptPayload({
    required ReceiptImage image,
    required List<AiCategoryRef> categories,
  }) = _ReceiptPayload;

  factory ReceiptPayload.fromJson(Map<String, dynamic> json) => _$ReceiptPayloadFromJson(json);
}

@freezed
abstract class ReceiptLineItem with _$ReceiptLineItem {
  const factory ReceiptLineItem({
    required String description,
    required String? quantity,
    required String amount,
  }) = _ReceiptLineItem;

  factory ReceiptLineItem.fromJson(Map<String, dynamic> json) => _$ReceiptLineItemFromJson(json);
}

@freezed
abstract class ReceiptChecks with _$ReceiptChecks {
  const factory ReceiptChecks({
    required bool? itemsMatchSubtotal,
    required bool? totalsConsistent,
  }) = _ReceiptChecks;

  factory ReceiptChecks.fromJson(Map<String, dynamic> json) => _$ReceiptChecksFromJson(json);
}

@freezed
abstract class ReceiptResult with _$ReceiptResult {
  const factory ReceiptResult({
    required bool isReceipt,

    /// `good | partial | poor`.
    required String legibility,
    required String? merchant,
    required String? date,
    required String? time,
    required String? currency,
    required String? subtotal,
    required String? tax,
    required String? tip,
    required String? total,
    required List<ReceiptLineItem> lineItems,
    required String? suggestedCategoryId,
    required ReceiptChecks checks,
  }) = _ReceiptResult;

  factory ReceiptResult.fromJson(Map<String, dynamic> json) => _$ReceiptResultFromJson(json);
}

// -------------------------------------------------------------- insights --

@freezed
abstract class InsightsPeriod with _$InsightsPeriod {
  const factory InsightsPeriod({
    /// `week | month`.
    required String kind,
    required String start,
    required String end,
  }) = _InsightsPeriod;

  factory InsightsPeriod.fromJson(Map<String, dynamic> json) => _$InsightsPeriodFromJson(json);
}

@freezed
abstract class MonthOverMonthStat with _$MonthOverMonthStat {
  const factory MonthOverMonthStat({
    required String ref,
    required String category,
    required String current,
    required String previous,
    required String deltaPct,
  }) = _MonthOverMonthStat;

  factory MonthOverMonthStat.fromJson(Map<String, dynamic> json) =>
      _$MonthOverMonthStatFromJson(json);
}

@freezed
abstract class AnomalyStat with _$AnomalyStat {
  const factory AnomalyStat({
    required String ref,
    required String date,
    required String merchant,
    required String category,
    required String amount,
    required String typical,
  }) = _AnomalyStat;

  factory AnomalyStat.fromJson(Map<String, dynamic> json) => _$AnomalyStatFromJson(json);
}

@freezed
abstract class SubscriptionStat with _$SubscriptionStat {
  const factory SubscriptionStat({
    required String ref,
    required String merchant,
    required String amount,
    required String cadence,

    /// `new | active | price_up | missed`.
    required String status,
    required String? priceChangePct,
  }) = _SubscriptionStat;

  factory SubscriptionStat.fromJson(Map<String, dynamic> json) => _$SubscriptionStatFromJson(json);
}

@freezed
abstract class BudgetPaceStat with _$BudgetPaceStat {
  const factory BudgetPaceStat({
    required String ref,
    required String category,
    required String limit,
    required String spent,
    required String expectedByToday,

    /// `on_track | at_risk | over`.
    required String status,
  }) = _BudgetPaceStat;

  factory BudgetPaceStat.fromJson(Map<String, dynamic> json) => _$BudgetPaceStatFromJson(json);
}

@freezed
abstract class GoalStat with _$GoalStat {
  const factory GoalStat({
    required String ref,
    required String name,
    required String target,
    required String saved,
    required String pct,
    required bool onTrack,
  }) = _GoalStat;

  factory GoalStat.fromJson(Map<String, dynamic> json) => _$GoalStatFromJson(json);
}

@freezed
abstract class InsightsStats with _$InsightsStats {
  const factory InsightsStats({
    required List<MonthOverMonthStat> monthOverMonth,
    required List<AnomalyStat> anomalies,
    required List<SubscriptionStat> subscriptions,
    required List<BudgetPaceStat> budgetPace,
    required List<GoalStat> goals,
  }) = _InsightsStats;

  factory InsightsStats.fromJson(Map<String, dynamic> json) => _$InsightsStatsFromJson(json);
}

@freezed
abstract class InsightsPayload with _$InsightsPayload {
  const factory InsightsPayload({required InsightsPeriod period, required InsightsStats stats}) =
      _InsightsPayload;

  factory InsightsPayload.fromJson(Map<String, dynamic> json) => _$InsightsPayloadFromJson(json);
}

@freezed
abstract class InsightActionDto with _$InsightActionDto {
  const factory InsightActionDto({
    /// `none | review_transactions | adjust_budget | review_subscription | open_goal`.
    required String type,
    required String? targetRef,
  }) = _InsightActionDto;

  factory InsightActionDto.fromJson(Map<String, dynamic> json) => _$InsightActionDtoFromJson(json);
}

@freezed
abstract class InsightDto with _$InsightDto {
  const factory InsightDto({
    /// `spending_trend | anomaly | subscription | budget | goal | tip`.
    required String kind,

    /// `positive | info | warning | critical`.
    required String severity,
    required String title,
    required String body,
    required List<String> evidenceRefs,
    required InsightActionDto action,
  }) = _InsightDto;

  factory InsightDto.fromJson(Map<String, dynamic> json) => _$InsightDtoFromJson(json);
}

@freezed
abstract class InsightsResult with _$InsightsResult {
  const factory InsightsResult({required List<InsightDto> insights}) = _InsightsResult;

  factory InsightsResult.fromJson(Map<String, dynamic> json) => _$InsightsResultFromJson(json);
}

// --------------------------------------------------------------- budgets --

@freezed
abstract class BudgetLineStats with _$BudgetLineStats {
  const factory BudgetLineStats({
    required int monthsOfData,
    required String median,
    required String mean,
    required String min,
    required String max,
    required String lastMonth,
  }) = _BudgetLineStats;

  factory BudgetLineStats.fromJson(Map<String, dynamic> json) => _$BudgetLineStatsFromJson(json);
}

@freezed
abstract class BudgetLineOptions with _$BudgetLineOptions {
  const factory BudgetLineOptions({
    required String tight,
    required String balanced,
    required String relaxed,
  }) = _BudgetLineOptions;

  factory BudgetLineOptions.fromJson(Map<String, dynamic> json) =>
      _$BudgetLineOptionsFromJson(json);
}

@freezed
abstract class BudgetLineInput with _$BudgetLineInput {
  const factory BudgetLineInput({
    required String ref,
    required String category,
    required bool isFixed,
    required String? current,
    required BudgetLineStats stats,
    required BudgetLineOptions options,
  }) = _BudgetLineInput;

  factory BudgetLineInput.fromJson(Map<String, dynamic> json) => _$BudgetLineInputFromJson(json);
}

@freezed
abstract class BudgetSuggestionsPayload with _$BudgetSuggestionsPayload {
  const factory BudgetSuggestionsPayload({
    /// `save_more | balanced | flexible`.
    required String preference,
    required String? monthlyIncome,
    required List<BudgetLineInput> lines,
  }) = _BudgetSuggestionsPayload;

  factory BudgetSuggestionsPayload.fromJson(Map<String, dynamic> json) =>
      _$BudgetSuggestionsPayloadFromJson(json);
}

@freezed
abstract class BudgetSuggestionLine with _$BudgetSuggestionLine {
  const factory BudgetSuggestionLine({
    required String ref,

    /// `keep | tight | balanced | relaxed`.
    required String choice,
    required String amount,
    required String rationale,
  }) = _BudgetSuggestionLine;

  factory BudgetSuggestionLine.fromJson(Map<String, dynamic> json) =>
      _$BudgetSuggestionLineFromJson(json);
}

@freezed
abstract class BudgetSuggestionsResult with _$BudgetSuggestionsResult {
  const factory BudgetSuggestionsResult({
    required List<BudgetSuggestionLine> lines,
    required String summary,
  }) = _BudgetSuggestionsResult;

  factory BudgetSuggestionsResult.fromJson(Map<String, dynamic> json) =>
      _$BudgetSuggestionsResultFromJson(json);
}
