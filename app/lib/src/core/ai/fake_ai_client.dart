import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:coin_pilot/src/core/ai/ai_client.dart';
import 'package:coin_pilot/src/core/ai/ai_dtos.dart';
import 'package:coin_pilot/src/core/ai/chat_models.dart';
import 'package:coin_pilot/src/core/ai/raw_message.dart';
import 'package:coin_pilot/src/core/time/clock_provider.dart';

/// Deterministic, offline stand-in for the AI proxy. Used in development
/// (`AI_BACKEND=fake`) and tests so every AI flow works without a network,
/// Firebase project or API key. Behaviour is intentionally simple and
/// rule-based; it is never shown as real AI (`isDemo` is true).
final class FakeAiClient implements AiClient {
  FakeAiClient({Clock? clock, this.chatChunkDelay = Duration.zero})
    : _clock = clock ?? const Clock();

  final Clock _clock;

  /// Delay between streamed chat chunks (zero in tests).
  final Duration chatChunkDelay;

  int _toolCallCounter = 0;
  int _macCounter = 0;

  static const _model = 'demo';

  @override
  bool get isDemo => true;

  AiResponse<T> _respond<T>(String task, T result, {int charged = 0}) => AiResponse(
    result: result,
    credits: AiCredits(charged: charged, remaining: 250, resetsAt: _nextMonthStart()),
    meta: AiMeta(task: task, promptVersion: 'demo/v1', model: _model),
  );

  String _nextMonthStart() {
    final today = _clock.today();
    return DateTime.utc(today.year, today.month + 1).toIso8601String();
  }

  // ------------------------------------------------------------- tasks --

  @override
  Future<AiResponse<CategorizeResult>> categorize(
    AiRequestContext ctx,
    CategorizePayload payload,
  ) async {
    final results = [
      for (final tx in payload.transactions)
        _categorizeOne(tx, payload.categories, payload.corrections),
    ];
    return _respond('categorizeTransactions', CategorizeResult(results: results));
  }

  CategorizeResultItem _categorizeOne(
    CategorizeTransaction tx,
    List<AiCategoryRef> categories,
    List<CategorizeCorrection> corrections,
  ) {
    final text = tx.text.toLowerCase();
    for (final correction in corrections) {
      if (text.contains(correction.text.toLowerCase())) {
        return CategorizeResultItem(
          id: tx.id,
          categoryId: correction.categoryId,
          confidence: 0.9,
          merchant: _titleCase(correction.text),
          suggestRule: true,
        );
      }
    }
    const keywords = {
      'groceries': ['market', 'grocery', 'carrefour', 'spinneys', 'supermarket'],
      'dining out': ['restaurant', 'cafe', 'pizza', 'burger', 'kfc', 'mcdonald'],
      'coffee': ['coffee', 'starbucks', 'costa'],
      'taxi': ['uber', 'careem', 'taxi', 'lyft'],
      'fuel': ['fuel', 'petrol', 'shell', 'gas station'],
      'subscriptions': ['netflix', 'spotify', 'youtube', 'icloud'],
      'salary': ['salary', 'payroll'],
    };
    for (final entry in keywords.entries) {
      if (entry.value.any(text.contains)) {
        final match = categories.where((c) => c.name.toLowerCase().contains(entry.key));
        if (match.isNotEmpty) {
          return CategorizeResultItem(
            id: tx.id,
            categoryId: match.first.id,
            confidence: 0.6,
            merchant: _titleCase(tx.text.split(RegExp(r'\s+')).first),
            suggestRule: false,
          );
        }
      }
    }
    return CategorizeResultItem(
      id: tx.id,
      categoryId: null,
      confidence: 0,
      merchant: null,
      suggestRule: false,
    );
  }

  @override
  Future<AiResponse<QuickAddResult>> parseQuickAdd(
    AiRequestContext ctx,
    QuickAddPayload payload,
  ) async {
    final text = payload.text.toLowerCase();
    final amount = RegExp(r'(\d+(?:[.,]\d{1,3})?)').firstMatch(text)?.group(1)?.replaceAll(',', '.');
    final isIncome = RegExp(r'\b(salary|paid me|got paid|received|income|refund)\b').hasMatch(text);

    final daysAgo = RegExp(r'(\d+)\s+days?\s+ago').firstMatch(text);
    final date = text.contains('yesterday')
        ? const QuickAddDate(type: 'yesterday')
        : daysAgo != null
        ? QuickAddDate(type: 'days_ago', daysAgo: int.parse(daysAgo.group(1)!))
        : const QuickAddDate(type: 'today');

    final category = payload.categories
        .where((c) => text.contains(c.name.toLowerCase()))
        .firstOrNull;
    final merchant = RegExp(r'\bat\s+([a-z0-9][\w&\- ]*)').firstMatch(text)?.group(1)?.trim();

    final result = QuickAddResult(
      draft: QuickAddDraftDto(
        kind: isIncome ? 'income' : 'expense',
        amount: amount,
        currency: null,
        date: date,
        merchant: merchant == null ? null : _titleCase(merchant.split(' ').first),
        categoryId: category?.id,
        accountId: payload.accounts.length == 1 ? payload.accounts.single.id : null,
        toAccountId: null,
        note: null,
      ),
      confidence: amount == null ? 0.2 : 0.7,
      needsClarification: amount == null,
      question: amount == null ? 'How much was it?' : null,
    );
    return _respond('parseQuickAdd', result, charged: 1);
  }

  @override
  Future<AiResponse<ReceiptResult>> extractReceipt(
    AiRequestContext ctx,
    ReceiptPayload payload,
  ) async {
    final result = ReceiptResult(
      isReceipt: true,
      legibility: 'good',
      merchant: 'Demo Market',
      date: ctx.today.toIso(),
      time: '12:00',
      currency: ctx.currency,
      subtotal: '20.00',
      tax: '2.80',
      tip: null,
      total: '22.80',
      lineItems: const [
        ReceiptLineItem(description: 'Milk 1L', quantity: '2', amount: '6.00'),
        ReceiptLineItem(description: 'Bread', quantity: '1', amount: '4.00'),
        ReceiptLineItem(description: 'Coffee beans', quantity: '1', amount: '10.00'),
      ],
      suggestedCategoryId: payload.categories
          .where((c) => c.name.toLowerCase().contains('groceries'))
          .firstOrNull
          ?.id,
      checks: const ReceiptChecks(itemsMatchSubtotal: true, totalsConsistent: true),
    );
    return _respond('extractReceipt', result, charged: 4);
  }

  @override
  Future<AiResponse<InsightsResult>> generateInsights(
    AiRequestContext ctx,
    InsightsPayload payload,
  ) async {
    final insights = <InsightDto>[
      for (final pace in payload.stats.budgetPace.where((p) => p.status != 'on_track'))
        InsightDto(
          kind: 'budget',
          severity: pace.status == 'over' ? 'critical' : 'warning',
          title: '${pace.category} budget is ${pace.status == 'over' ? 'over' : 'at risk'}',
          body: 'You have spent ${pace.spent} of ${pace.limit} so far.',
          evidenceRefs: [pace.ref],
          action: InsightActionDto(type: 'adjust_budget', targetRef: pace.ref),
        ),
      for (final mom in payload.stats.monthOverMonth.where(
        (m) => (double.tryParse(m.deltaPct) ?? 0) >= 20,
      ))
        InsightDto(
          kind: 'spending_trend',
          severity: 'info',
          title: '${mom.category} is up ${mom.deltaPct}%',
          body: '${mom.current} this period vs ${mom.previous} last period.',
          evidenceRefs: [mom.ref],
          action: InsightActionDto(type: 'review_transactions', targetRef: mom.ref),
        ),
    ];
    return _respond('generateInsights', InsightsResult(insights: insights.take(6).toList()), charged: 5);
  }

  @override
  Future<AiResponse<BudgetSuggestionsResult>> suggestBudgets(
    AiRequestContext ctx,
    BudgetSuggestionsPayload payload,
  ) async {
    final result = BudgetSuggestionsResult(
      lines: [
        for (final line in payload.lines)
          BudgetSuggestionLine(
            ref: line.ref,
            choice: 'balanced',
            amount: line.options.balanced,
            rationale: 'Close to your typical month.',
          ),
      ],
      summary: 'Balanced limits based on your recent months (demo).',
    );
    return _respond('suggestBudgets', result, charged: 5);
  }

  @override
  Future<AiUsage> getUsage() async =>
      AiUsage(creditsUsed: 0, creditsLimit: 250, remaining: 250, resetsAt: _nextMonthStart());

  @override
  Future<void> deleteMyData() async {}

  // -------------------------------------------------------------- chat --

  @override
  Stream<ChatEvent> chat(ChatRequest request) async* {
    final tail = request.messages.last;
    yield const ChatMetaEvent(promptVersion: 'demo/v1', model: _model);

    final Map<String, Object?> assistant;
    final List<PendingToolUse> toolUses;
    if (tail.hasToolResults) {
      final text = _answerFromToolResults(tail);
      yield* _streamText(text);
      assistant = _assistantMessage([_textBlock(text)]);
      toolUses = const [];
    } else {
      final question = tail.visibleText.toLowerCase();
      final toolUse = _toolFor(question);
      if (toolUse == null) {
        const text =
            "I'm Pilot's offline demo. Try asking \"How much did I spend this month?\" or "
            '"What are my account balances?". Real answers come from Claude once the AI '
            'backend is connected.';
        yield* _streamText(text);
        assistant = _assistantMessage([_textBlock(text)]);
        toolUses = const [];
      } else {
        const preface = 'Let me check that for you.';
        yield* _streamText(preface);
        yield ChatToolEvent(toolUse.name);
        assistant = _assistantMessage([
          _textBlock(preface),
          {'type': 'tool_use', 'id': toolUse.id, 'name': toolUse.name, 'input': toolUse.input},
        ]);
        toolUses = [toolUse];
      }
    }

    yield ChatFinalEvent(
      append: [tail, RawMessage.fromReceived(assistant)],
      stopReason: toolUses.isEmpty ? 'end_turn' : 'tool_use',
      pendingToolUses: toolUses,
      historyMac: 'demo-mac-${++_macCounter}',
    );
  }

  PendingToolUse? _toolFor(String question) {
    final id = 'toolu_demo_${++_toolCallCounter}';
    if (RegExp(r'spen[dt]|expens|cost').hasMatch(question)) {
      final today = _clock.today();
      return PendingToolUse(
        id: id,
        name: 'get_spending_summary',
        input: {
          'date_from': today.startOfMonth.toIso(),
          'date_to': today.toIso(),
          'flow': 'expense',
          'group_by': 'category',
          'category_ids': const <String>[],
          'top_n': 5,
        },
      );
    }
    if (RegExp(r'balance|account|how much (do|have) i').hasMatch(question)) {
      return PendingToolUse(id: id, name: 'get_accounts', input: const {});
    }
    _toolCallCounter--;
    return null;
  }

  String _answerFromToolResults(RawMessage tail) {
    final block = tail.blocks.firstWhere((b) => b['type'] == 'tool_result');
    if (block['is_error'] == true) {
      return "I couldn't look that up on this device (${block['content']}).";
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(block['content']! as String);
    } on FormatException {
      return 'Here is what I found: ${block['content']}';
    }
    if (decoded is Map && decoded['groups'] is List) {
      final groups = (decoded['groups'] as List).cast<Map<String, Object?>>();
      if (groups.isEmpty) return 'I found no spending in that period yet.';
      final lines = groups.take(3).map((g) => '• ${g['label']}: ${g['total']}').join('\n');
      return 'Your top spending so far (${decoded['currency']}):\n$lines\n'
          'Total: ${decoded['total']}.';
    }
    if (decoded is Map && decoded['accounts'] is List) {
      final accounts = (decoded['accounts'] as List).cast<Map<String, Object?>>();
      if (accounts.isEmpty) return 'You have no accounts yet.';
      final lines = accounts.map((a) => '• ${a['name']}: ${a['balance']} ${a['currency']}');
      return 'Your balances:\n${lines.join('\n')}';
    }
    return 'Here is what I found: ${block['content']}';
  }

  Stream<ChatEvent> _streamText(String text) async* {
    for (final chunk in RegExp(r'\S+\s*').allMatches(text)) {
      if (chatChunkDelay > Duration.zero) await Future<void>.delayed(chatChunkDelay);
      yield ChatTextEvent(chunk.group(0)!);
    }
  }

  static Map<String, Object?> _assistantMessage(List<Map<String, Object?>> content) => {
    'role': 'assistant',
    'content': content,
  };

  static Map<String, Object?> _textBlock(String text) => {'type': 'text', 'text': text};

  static String _titleCase(String value) => value.isEmpty
      ? value
      : value
            .split(' ')
            .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
            .join(' ');
}
