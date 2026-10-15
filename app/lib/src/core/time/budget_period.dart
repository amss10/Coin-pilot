import 'package:coin_pilot/src/core/time/local_date.dart';
import 'package:meta/meta.dart';

/// A budget period: one "month" that starts on the user's cycle day (1–28),
/// e.g. the 25th for someone paid on the 25th. [end] is exclusive.
@immutable
final class BudgetPeriod {
  const BudgetPeriod._(this.start, this.end, this.cycleStartDay);

  /// The period that contains [date] for a cycle starting on [cycleStartDay].
  factory BudgetPeriod.containing(LocalDate date, {required int cycleStartDay}) {
    _checkCycleDay(cycleStartDay);
    final startMonthIndex = date.day >= cycleStartDay ? date.monthIndex : date.monthIndex - 1;
    return BudgetPeriod.startingInMonth(startMonthIndex, cycleStartDay: cycleStartDay);
  }

  /// The period that starts in the month with absolute [monthIndex].
  factory BudgetPeriod.startingInMonth(int monthIndex, {required int cycleStartDay}) {
    _checkCycleDay(cycleStartDay);
    final start = LocalDate.fromMonthIndex(monthIndex, day: cycleStartDay);
    final end = LocalDate.fromMonthIndex(monthIndex + 1, day: cycleStartDay);
    return BudgetPeriod._(start, end, cycleStartDay);
  }

  static void _checkCycleDay(int day) {
    if (day < 1 || day > 28) {
      throw ArgumentError.value(day, 'cycleStartDay', 'Must be between 1 and 28');
    }
  }

  /// First day of the period (inclusive).
  final LocalDate start;

  /// First day of the next period (exclusive).
  final LocalDate end;

  final int cycleStartDay;

  /// Last day of the period (inclusive).
  LocalDate get lastDay => end.addDays(-1);

  int get lengthInDays => start.daysUntil(end);

  /// Stable label of the period: the `YYYY-MM` it starts in.
  String get key => start.yearMonth;

  BudgetPeriod get next => BudgetPeriod.startingInMonth(start.monthIndex + 1, cycleStartDay: cycleStartDay);

  BudgetPeriod get previous =>
      BudgetPeriod.startingInMonth(start.monthIndex - 1, cycleStartDay: cycleStartDay);

  bool contains(LocalDate date) => date >= start && date < end;

  /// Days elapsed including [today], clamped to the period length.
  int daysElapsed(LocalDate today) {
    if (today < start) return 0;
    if (today >= end) return lengthInDays;
    return start.daysUntil(today) + 1;
  }

  @override
  bool operator ==(Object other) =>
      other is BudgetPeriod && other.start == start && other.cycleStartDay == cycleStartDay;

  @override
  int get hashCode => Object.hash(start, cycleStartDay);

  @override
  String toString() => 'BudgetPeriod(${start.toIso()} – ${lastDay.toIso()})';
}
