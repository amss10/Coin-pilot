import 'package:coin_pilot/src/core/database/tables/sync_columns.dart';
import 'package:coin_pilot/src/core/finance/enums.dart';
import 'package:drift/drift.dart';

/// A money account. Its balance is never stored: it is the sum of its
/// transactions, including the `openingBalance` entry.
@DataClassName('AccountRow')
class Accounts extends Table with SyncColumns {
  TextColumn get name => text().withLength(min: 1, max: 60)();
  TextColumn get type => textEnum<AccountType>()();
  TextColumn get currencyCode => text().withLength(min: 3, max: 3)();
  BoolColumn get includeInNetWorth => boolean().withDefault(const Constant(true))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get iconKey => text().nullable()();

  /// ARGB colour.
  IntColumn get color => integer().nullable()();
}
