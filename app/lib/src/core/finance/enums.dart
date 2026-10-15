/// Financial enums shared by the database schema and the domain models.
///
/// These are stored in SQLite by their `name` (Drift `textEnum`), so a value
/// must **never be renamed** without a schema migration.
library;

/// Kind of money account.
enum AccountType { cash, checking, savings, creditCard, ewallet, other }

/// Whether a category tracks spending or income.
enum CategoryKind { expense, income }

/// What a transaction row represents. Only [standard] rows count as income or
/// spending; the others move or correct balances.
enum EntryType { standard, transfer, adjustment, openingBalance }

/// Who chose the category of a transaction or split.
enum CategorySource { none, user, rule, ai, imported }

/// How a transaction entered the app.
enum TransactionSource { manual, quickAdd, voice, receipt, csvImport, recurring }

/// What happens to unspent (or overspent) budget at the end of a period.
enum RolloverMode {
  /// Every period starts fresh.
  none,

  /// Unspent money carries forward; overspending does not.
  surplus,

  /// Both unspent money and overspending carry forward.
  surplusAndOverspend,
}

/// Kind of recurring rule.
enum RecurringKind { expense, income, transfer }

/// Lifecycle of a savings goal.
enum GoalStatus { active, achieved, archived }

/// State of AI extraction for a stored receipt image.
enum ExtractionStatus { none, pending, done, failed }

/// How a merchant rule matches a normalised payee.
enum MatchType { exact, prefix, contains }

/// Where a merchant rule came from.
enum RuleOrigin { user, learned, system }

/// Lifecycle of a Pilot chat conversation.
enum ConversationStatus { open, closed, retired }

/// Direction filter used by queries and AI tools.
enum FlowFilter { any, expense, income }

/// Wire names used by the AI contract (snake_case) for [AccountType].
extension AccountTypeWire on AccountType {
  String get wireName => switch (this) {
    AccountType.cash => 'cash',
    AccountType.checking => 'checking',
    AccountType.savings => 'savings',
    AccountType.creditCard => 'credit_card',
    AccountType.ewallet => 'ewallet',
    AccountType.other => 'other',
  };
}
