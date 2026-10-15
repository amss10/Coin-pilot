import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/common.dart';

/// File name (without extension) of the on-device database. Android backup
/// rules (`android/app/src/main/res/xml/*backup*.xml`) refer to it.
const String databaseName = 'coin_pilot';

/// Opens the on-device database in Application Support (not Documents, which
/// is user-visible on some platforms).
QueryExecutor openAppDatabaseConnection() => driftDatabase(
  name: databaseName,
  native: const DriftNativeOptions(
    databaseDirectory: getApplicationSupportDirectory,
    setup: configureSqliteConnection,
  ),
);

/// Runs on every new SQLite connection (on the database isolate, so it must
/// stay a top-level function without captured state).
///
/// Encryption seam (ADR 0005): when SQLite3MultipleCiphers is enabled, the
/// `PRAGMA key` statement goes first in this function.
void configureSqliteConnection(CommonDatabase db) {
  db.execute('PRAGMA journal_mode = WAL;');
}
