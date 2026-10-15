import 'package:coin_pilot/src/core/database/converters/local_date_converter.dart';
import 'package:coin_pilot/src/core/database/tables/categories.dart';
import 'package:coin_pilot/src/core/database/tables/sync_columns.dart';
import 'package:coin_pilot/src/core/finance/enums.dart';
import 'package:drift/drift.dart';

@DataClassName('BudgetRow')
class Budgets extends Table with SyncColumns {
  TextColumn get name => text().withLength(min: 1, max: 60)();
  TextColumn get currencyCode => text().withLength(min: 3, max: 3)();

  /// Day of month each budget period starts on (1–28).
  IntColumn get cycleStartDay => integer().check(cycleStartDay.isBetweenValues(1, 28))();
  TextColumn get startsOn => text().map(const LocalDateConverter())();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

/// One budgeted category (covers its child categories too).
@DataClassName('BudgetLineRow')
@TableIndex.sql(
  'CREATE UNIQUE INDEX ux_budget_lines_category ON budget_lines (budget_id, category_id) '
  'WHERE deleted_at IS NULL',
)
class BudgetLines extends Table with SyncColumns {
  TextColumn get budgetId => text().references(Budgets, #id)();
  TextColumn get categoryId => text().references(Categories, #id)();
  TextColumn get rolloverMode => textEnum<RolloverMode>()();
}

/// Effective-dated limits: a limit applies from [effectiveFrom] until a later
/// one supersedes it, so editing a limit never rewrites past months.
@DataClassName('BudgetLineLimitRow')
@TableIndex.sql(
  'CREATE UNIQUE INDEX ux_budget_limits_effective ON budget_line_limits '
  '(budget_line_id, effective_from) WHERE deleted_at IS NULL',
)
class BudgetLineLimits extends Table with SyncColumns {
  TextColumn get budgetLineId => text().references(BudgetLines, #id)();
  TextColumn get effectiveFrom => text().map(const LocalDateConverter())();
  IntColumn get limitMinor => integer()();
}
