import 'package:coin_pilot/src/core/database/converters/local_date_converter.dart';
import 'package:coin_pilot/src/core/database/tables/accounts.dart';
import 'package:coin_pilot/src/core/database/tables/categories.dart';
import 'package:coin_pilot/src/core/database/tables/sync_columns.dart';
import 'package:coin_pilot/src/core/finance/enums.dart';
import 'package:drift/drift.dart';

/// One row = one entry on one account. A transfer is two rows sharing a
/// [transferGroupId]; an opening balance is a row with
/// `entry_type = openingBalance`.
@DataClassName('TransactionRow')
@TableIndex.sql(
  'CREATE INDEX idx_tx_booked_on ON transactions (booked_on) WHERE deleted_at IS NULL',
)
@TableIndex.sql(
  'CREATE INDEX idx_tx_account_date ON transactions (account_id, booked_on) '
  'WHERE deleted_at IS NULL',
)
@TableIndex.sql(
  'CREATE INDEX idx_tx_category_date ON transactions (category_id, booked_on) '
  'WHERE deleted_at IS NULL',
)
@TableIndex.sql(
  'CREATE INDEX idx_tx_transfer_group ON transactions (transfer_group_id) '
  'WHERE transfer_group_id IS NOT NULL',
)
@TableIndex.sql(
  'CREATE UNIQUE INDEX ux_tx_recurring_occurrence ON transactions '
  '(recurring_rule_id, recurring_occurrence_on) '
  'WHERE recurring_rule_id IS NOT NULL AND deleted_at IS NULL',
)
@TableIndex.sql(
  'CREATE UNIQUE INDEX ux_tx_import_fingerprint ON transactions '
  '(account_id, import_fingerprint) '
  'WHERE import_fingerprint IS NOT NULL AND deleted_at IS NULL',
)
class Transactions extends Table with SyncColumns {
  TextColumn get accountId => text().references(Accounts, #id)();
  TextColumn get bookedOn => text().map(const LocalDateConverter())();

  /// Signed minor units: negative = money out of the account.
  IntColumn get amountMinor => integer()();
  TextColumn get currencyCode => text().withLength(min: 3, max: 3)();
  TextColumn get entryType => textEnum<EntryType>()();

  TextColumn get payeeRaw => text().nullable()();
  TextColumn get merchant => text().nullable()();
  TextColumn get note => text().nullable()();

  /// Null when the transaction is split or is a transfer.
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  TextColumn get categorySource => textEnum<CategorySource>()();
  RealColumn get aiConfidence => real().nullable()();
  BoolColumn get needsReview => boolean().withDefault(const Constant(false))();

  TextColumn get source => textEnum<TransactionSource>()();
  TextColumn get transferGroupId => text().nullable()();
  TextColumn get receiptId => text().nullable()();
  TextColumn get recurringRuleId => text().nullable()();
  TextColumn get recurringOccurrenceOn => text().map(const LocalDateConverter()).nullable()();
  TextColumn get importBatchId => text().nullable()();
  TextColumn get importFingerprint => text().nullable()();

  /// For card spend in a foreign currency: what the merchant charged.
  IntColumn get originalAmountMinor => integer().nullable()();
  TextColumn get originalCurrencyCode => text().nullable()();
}

/// Category split lines. They must sum to the parent transaction's amount.
@DataClassName('TransactionSplitRow')
@TableIndex.sql(
  'CREATE INDEX idx_splits_transaction ON transaction_splits (transaction_id) '
  'WHERE deleted_at IS NULL',
)
class TransactionSplits extends Table with SyncColumns {
  TextColumn get transactionId => text().references(Transactions, #id)();
  TextColumn get categoryId => text().references(Categories, #id)();
  IntColumn get amountMinor => integer()();
  TextColumn get note => text().nullable()();
  TextColumn get categorySource => textEnum<CategorySource>()();
  RealColumn get aiConfidence => real().nullable()();
}
