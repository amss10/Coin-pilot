import 'package:coin_pilot/src/core/time/local_date.dart';
import 'package:meta/meta.dart';

/// How often a recurring rule repeats. Stored by name in SQLite.
enum Frequency { daily, weekly, monthly, yearly }

/// A repeating schedule anchored on its first occurrence.
///
/// - weekly rules repeat on the anchor's weekday;
/// - monthly rules use [byMonthDay] (or the anchor's day), clamped to short
///   months; `-1` means "last day of the month";
/// - yearly rules repeat on the anchor's month and day (Feb 29 → Feb 28).
@immutable
final class Recurrence {
  Recurrence({
    required this.frequency,
    required this.anchor,
    this.interval = 1,
    this.byMonthDay,
    this.endsOn,
  }) {
    if (interval < 1) throw ArgumentError.value(interval, 'interval', 'Must be >= 1');
    final day = byMonthDay;
    if (day != null && day != -1 && (day < 1 || day > 31)) {
      throw ArgumentError.value(day, 'byMonthDay', 'Must be 1..31 or -1');
    }
  }

  final Frequency frequency;
  final LocalDate anchor;
  final int interval;
  final int? byMonthDay;
  final LocalDate? endsOn;

  /// The [n]-th occurrence (0-based), or null when it falls after [endsOn].
  LocalDate? occurrence(int n) {
    if (n < 0) return null;
    final date = _raw(n);
    final end = endsOn;
    if (end != null && date > end) return null;
    return date;
  }

  LocalDate _raw(int n) {
    switch (frequency) {
      case Frequency.daily:
        return anchor.addDays(n * interval);
      case Frequency.weekly:
        return anchor.addDays(n * interval * 7);
      case Frequency.monthly:
        final index = anchor.monthIndex + n * interval;
        return LocalDate.fromMonthIndex(index, day: byMonthDay ?? anchor.day);
      case Frequency.yearly:
        return LocalDate.fromMonthIndex(anchor.monthIndex + n * interval * 12, day: anchor.day);
    }
  }

  /// First occurrence on or after [date], or null if the schedule has ended.
  LocalDate? firstOnOrAfter(LocalDate date) {
    if (date <= anchor) return occurrence(0);
    var n = _estimateIndex(date);
    // The estimate is never more than one step off; walk to the exact answer.
    while (n > 0 && _raw(n - 1) >= date) {
      n--;
    }
    while (_raw(n) < date) {
      n++;
    }
    return occurrence(n);
  }

  int _estimateIndex(LocalDate date) {
    switch (frequency) {
      case Frequency.daily:
        return anchor.daysUntil(date) ~/ interval;
      case Frequency.weekly:
        return anchor.daysUntil(date) ~/ (7 * interval);
      case Frequency.monthly:
        return (date.monthIndex - anchor.monthIndex) ~/ interval;
      case Frequency.yearly:
        return (date.year - anchor.year) ~/ interval;
    }
  }

  /// Occurrences between [from] and [to], both inclusive (at most [limit]).
  List<LocalDate> between(LocalDate from, LocalDate to, {int limit = 500}) {
    final result = <LocalDate>[];
    var next = firstOnOrAfter(from);
    if (next == null) return result;
    var n = _indexOf(next);
    while (next != null && next <= to && result.length < limit) {
      result.add(next);
      n++;
      next = occurrence(n);
    }
    return result;
  }

  int _indexOf(LocalDate occurrenceDate) {
    var n = _estimateIndex(occurrenceDate);
    while (n > 0 && _raw(n) > occurrenceDate) {
      n--;
    }
    while (_raw(n) < occurrenceDate) {
      n++;
    }
    return n;
  }
}
