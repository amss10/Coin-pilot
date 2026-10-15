import 'package:coin_pilot/src/core/database/converters/local_date_converter.dart';
import 'package:coin_pilot/src/core/database/tables/accounts.dart';
import 'package:coin_pilot/src/core/database/tables/categories.dart';
import 'package:coin_pilot/src/core/database/tables/sync_columns.dart';
import 'package:coin_pilot/src/core/finance/enums.dart';
import 'package:drift/drift.dart';

/// Receipt photos. The image lives under Application Support; the path is
/// stored **relative** because the iOS app container path changes.
@DataClassName('ReceiptRow')
class Receipts extends Table with SyncColumns {
  TextColumn get relativePath => text()();
  TextColumn get sha256 => text()();
  TextColumn get mimeType => text()();
  IntColumn get byteSize => integer()();
  TextColumn get extractionStatus => textEnum<ExtractionStatus>()();
  TextColumn get extractedJson => text().nullable()();
  TextColumn get model => text().nullable()();
  TextColumn get promptVersion => text().nullable()();
  TextColumn get merchant => text().nullable()();
  IntColumn get totalMinor => integer().nullable()();
  TextColumn get receiptOn => text().map(const LocalDateConverter()).nullable()();
}

/// Local categorisation rules, matched before anything is sent to the AI.
@DataClassName('MerchantRuleRow')
class MerchantRules extends Table with SyncColumns {
  TextColumn get matchType => textEnum<MatchType>()();
  TextColumn get patternNormalized => text().withLength(min: 1, max: 120)();
  TextColumn get merchantName => text().nullable()();
  TextColumn get categoryId => text().references(Categories, #id)();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  TextColumn get origin => textEnum<RuleOrigin>()();
  IntColumn get hitCount => integer().withDefault(const Constant(0))();
}

/// Saved CSV column mappings, keyed by a hash of the header row.
@DataClassName('ImportProfileRow')
class ImportProfiles extends Table with SyncColumns {
  TextColumn get name => text()();
  TextColumn get headerSignature => text()();
  TextColumn get mappingJson => text()();
  TextColumn get accountId => text().nullable().references(Accounts, #id)();
}

/// One CSV import run; lets the user undo a whole import.
@DataClassName('ImportBatchRow')
class ImportBatches extends Table with SyncColumns {
  TextColumn get fileName => text()();
  TextColumn get accountId => text().references(Accounts, #id)();
  TextColumn get profileId => text().nullable().references(ImportProfiles, #id)();
  IntColumn get rowCount => integer()();
  IntColumn get importedCount => integer()();
  IntColumn get skippedCount => integer()();
  DateTimeColumn get undoneAt => dateTime().nullable()();
}
