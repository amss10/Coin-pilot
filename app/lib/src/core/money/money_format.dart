import 'package:coin_pilot/src/core/money/money.dart';
import 'package:intl/intl.dart';

/// Formats [Money] for display in a given locale, e.g. `$1,234.50`.
///
/// Formatting is the only place money becomes a double, and only after the
/// decimals have been fixed by the currency, so no rounding error can show.
final class MoneyFormatter {
  MoneyFormatter(this.locale);

  final String locale;
  final Map<String, NumberFormat> _cache = {};

  /// Formats with the currency symbol. When [showPlusSign] is true positive
  /// amounts get a leading `+` (useful for income).
  String format(Money money, {bool showPlusSign = false}) {
    final formatted = _formatterFor(money).format(money.toDisplayDouble());
    return showPlusSign && money.isPositive ? '+$formatted' : formatted;
  }

  /// Formats without the sign (for lists that colour amounts instead).
  String formatAbs(Money money) => format(money.abs());

  NumberFormat _formatterFor(Money money) {
    final code = money.currency.code;
    return _cache.putIfAbsent(
      code,
      () => NumberFormat.simpleCurrency(
        locale: locale,
        name: code,
        decimalDigits: money.currency.decimals,
      ),
    );
  }
}
