import 'package:drift/drift.dart';

/// Columns every syncable table has (see ADR 0001: the schema stays
/// sync-ready even though v1 is device-only).
mixin SyncColumns on Table {
  /// UUIDv7 primary key.
  TextColumn get id => text()();

  /// UTC timestamps, stored as ISO-8601 text.
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  /// Soft delete marker; rows are never hard-deleted by normal flows.
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
