import 'package:meta/meta.dart';

/// A calendar date without time or time zone, e.g. the day a purchase was
/// booked. Stored as `YYYY-MM-DD`. Arithmetic runs on UTC midnights so
/// daylight-saving changes can never shift a date.
@immutable
final class LocalDate implements Comparable<LocalDate> {
  const LocalDate._(this.year, this.month, this.day);

  /// Throws [ArgumentError] for impossible dates such as 2026-02-30.
  factory LocalDate(int year, int month, int day) {
    if (month < 1 || month > 12 || day < 1 || day > daysInMonth(year, month)) {
      throw ArgumentError('Invalid date $year-$month-$day');
    }
    return LocalDate._(year, month, day);
  }

  /// Uses the calendar fields of [dateTime] in its own time zone.
  factory LocalDate.fromDateTime(DateTime dateTime) =>
      LocalDate._(dateTime.year, dateTime.month, dateTime.day);

  /// Parses `YYYY-MM-DD`. Throws [FormatException] otherwise.
  factory LocalDate.parse(String iso) {
    final date = tryParse(iso);
    if (date == null) throw FormatException('Expected YYYY-MM-DD', iso);
    return date;
  }

  /// First day of the month with the given absolute [index] (see [monthIndex]).
  factory LocalDate.fromMonthIndex(int index, {int day = 1}) {
    final year = index ~/ 12;
    final month = index % 12 + 1;
    final clamped = day < 0 ? daysInMonth(year, month) : day.clamp(1, daysInMonth(year, month));
    return LocalDate._(year, month, clamped);
  }

  static LocalDate? tryParse(String? iso) {
    if (iso == null) return null;
    final match = _isoPattern.firstMatch(iso);
    if (match == null) return null;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    if (month < 1 || month > 12 || day < 1 || day > daysInMonth(year, month)) return null;
    return LocalDate._(year, month, day);
  }

  static final RegExp _isoPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  static int daysInMonth(int year, int month) => DateTime.utc(year, month + 1, 0).day;

  final int year;
  final int month;
  final int day;

  DateTime get _utc => DateTime.utc(year, month, day);

  /// ISO weekday: 1 = Monday … 7 = Sunday.
  int get weekday => _utc.weekday;

  /// Months since year 0, handy for month arithmetic.
  int get monthIndex => year * 12 + (month - 1);

  LocalDate get startOfMonth => LocalDate._(year, month, 1);
  LocalDate get endOfMonth => LocalDate._(year, month, daysInMonth(year, month));

  LocalDate addDays(int days) => LocalDate.fromDateTime(_utc.add(Duration(days: days)));

  /// Adds months, clamping the day to the target month (Jan 31 + 1 → Feb 28/29).
  LocalDate addMonths(int months) => LocalDate.fromMonthIndex(monthIndex + months, day: day);

  LocalDate addYears(int years) => addMonths(years * 12);

  /// Whole days from this date to [other] (negative if [other] is earlier).
  int daysUntil(LocalDate other) => other._utc.difference(_utc).inDays;

  /// Local midnight of this date.
  DateTime toDateTime() => DateTime(year, month, day);

  String toIso() =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  /// `YYYY-MM`.
  String get yearMonth => toIso().substring(0, 7);

  bool isBefore(LocalDate other) => compareTo(other) < 0;
  bool isAfter(LocalDate other) => compareTo(other) > 0;
  bool operator <(LocalDate other) => compareTo(other) < 0;
  bool operator <=(LocalDate other) => compareTo(other) <= 0;
  bool operator >(LocalDate other) => compareTo(other) > 0;
  bool operator >=(LocalDate other) => compareTo(other) >= 0;

  @override
  int compareTo(LocalDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is LocalDate && other.year == year && other.month == month && other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toIso();
}
