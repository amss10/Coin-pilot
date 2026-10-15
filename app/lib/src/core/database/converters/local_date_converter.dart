import 'package:coin_pilot/src/core/time/local_date.dart';
import 'package:drift/drift.dart';

/// Stores a [LocalDate] as `YYYY-MM-DD` text, which also sorts correctly.
class LocalDateConverter extends TypeConverter<LocalDate, String> {
  const LocalDateConverter();

  @override
  LocalDate fromSql(String fromDb) => LocalDate.parse(fromDb);

  @override
  String toSql(LocalDate value) => value.toIso();
}
