import 'package:coin_pilot/src/core/database/converters/local_date_converter.dart';
import 'package:coin_pilot/src/core/database/tables/sync_columns.dart';
import 'package:coin_pilot/src/core/finance/enums.dart';
import 'package:drift/drift.dart';

/// A Pilot chat conversation, pinned to one prompt version.
@DataClassName('AiConversationRow')
class AiConversations extends Table with SyncColumns {
  TextColumn get title => text().nullable()();
  TextColumn get promptVersion => text().nullable()();
  TextColumn get model => text().nullable()();

  /// Latest history signature issued by the proxy (see ADR 0006).
  TextColumn get historyMac => text().nullable()();
  TextColumn get status => textEnum<ConversationStatus>()();
}

/// Append-only chat messages. [rawJson] is the message exactly as received
/// from the proxy and is replayed verbatim; it is never edited or re-encoded.
@DataClassName('AiMessageRow')
class AiMessages extends Table with SyncColumns {
  TextColumn get conversationId => text().references(AiConversations, #id)();
  IntColumn get seq => integer()();
  TextColumn get role => text()();
  TextColumn get rawJson => text()();
  TextColumn get stopReason => text().nullable()();
  TextColumn get usageJson => text().nullable()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {conversationId, seq},
  ];
}

/// Generated insights, cached by a hash of the statistics they were built from.
@DataClassName('AiInsightRow')
class AiInsights extends Table with SyncColumns {
  TextColumn get kind => text()();
  TextColumn get severity => text()();
  TextColumn get periodKind => text()();
  TextColumn get periodStart => text().map(const LocalDateConverter())();
  TextColumn get periodEnd => text().map(const LocalDateConverter())();
  TextColumn get payloadJson => text()();
  TextColumn get statsHash => text()();
  TextColumn get promptVersion => text().nullable()();
  DateTimeColumn get dismissedAt => dateTime().nullable()();
}

/// Key-value app settings (`value_json` holds a JSON-encoded value).
@DataClassName('AppSettingRow')
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get valueJson => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
