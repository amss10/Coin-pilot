import 'package:coin_pilot/src/core/database/converters/local_date_converter.dart';
import 'package:coin_pilot/src/core/database/tables/accounts.dart';
import 'package:coin_pilot/src/core/database/tables/categories.dart';
import 'package:coin_pilot/src/core/database/tables/sync_columns.dart';
import 'package:coin_pilot/src/core/database/tables/transactions.dart';
import 'package:coin_pilot/src/core/finance/enums.dart';
import 'package:coin_pilot/src/core/time/recurrence.dart';
import 'package:drift/drift.dart';

/// Bills, subscriptions, salaries and scheduled transfers.
@DataClassName('RecurringRuleRow')
class RecurringRules extends Table with SyncColumns {
  TextColumn get name => text().withLength(min: 1, max: 60)();
  TextColumn get kind => textEnum<RecurringKind>()();
  @ReferenceName('recurringRulesFrom')
  TextColumn get accountId => text().references(Accounts, #id)();
  @ReferenceName('recurringRulesTo')
  TextColumn get toAccountId => text().nullable().references(Accounts, #id)();

  /// Expected amount as a positive magnitude; [kind] gives the direction.
  IntColumn get amountMinor => integer()();
  TextColumn get currencyCode => text().withLength(min: 3, max: 3)();
  BoolColumn get isVariable => boolean().withDefault(const Constant(false))();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  TextColumn get payee => text().nullable()();

  TextColumn get frequency => textEnum<Frequency>()();
  IntColumn get interval => integer().withDefault(const Constant(1))();
  TextColumn get anchorOn => text().map(const LocalDateConverter())();

  /// Day of month for monthly rules; -1 means the last day.
  IntColumn get byMonthDay => integer().nullable()();
  TextColumn get endsOn => text().map(const LocalDateConverter()).nullable()();
  TextColumn get nextDueOn => text().map(const LocalDateConverter())();

  BoolColumn get autoPost => boolean().withDefault(const Constant(false))();
  IntColumn get remindDaysBefore => integer().nullable()();
  BoolColumn get isSubscription => boolean().withDefault(const Constant(false))();
  BoolColumn get isPaused => boolean().withDefault(const Constant(false))();
}

@DataClassName('GoalRow')
class Goals extends Table with SyncColumns {
  TextColumn get name => text().withLength(min: 1, max: 60)();
  IntColumn get targetMinor => integer()();
  TextColumn get currencyCode => text().withLength(min: 3, max: 3)();
  TextColumn get targetOn => text().map(const LocalDateConverter()).nullable()();

  /// When set, progress is that account's balance instead of contributions.
  TextColumn get linkedAccountId => text().nullable().references(Accounts, #id)();
  TextColumn get iconKey => text().nullable()();
  IntColumn get color => integer().nullable()();
  TextColumn get status => textEnum<GoalStatus>()();
}

@DataClassName('GoalContributionRow')
class GoalContributions extends Table with SyncColumns {
  TextColumn get goalId => text().references(Goals, #id)();
  IntColumn get amountMinor => integer()();
  TextColumn get occurredOn => text().map(const LocalDateConverter())();
  TextColumn get transactionId => text().nullable().references(Transactions, #id)();
  TextColumn get note => text().nullable()();
}
