import 'package:coin_pilot/src/core/money/currency.dart';
import 'package:coin_pilot/src/core/money/money.dart';
import 'package:intl/intl.dart';
import 'package:intl/number_symbols.dart';

/// Parses amounts typed by people, e.g. `1,234.5` (en) or `1.234,5` (de),
/// into exact [Money] without going through floating point.
final class MoneyInputParser {
  MoneyInputParser(String locale) : _symbols = NumberFormat.decimalPattern(locale).symbols;

  final NumberSymbols _symbols;

  /// Returns null when [text] is empty or not a valid amount for [currency].
  /// A leading minus sign makes the amount negative.
  Money? parse(String text, Currency currency) {
    var cleaned = text.trim();
    if (cleaned.isEmpty) return null;

    final negative = cleaned.startsWith('-') || cleaned.startsWith('−');
    cleaned = cleaned.replaceAll(RegExp(r'[\s  ]'), '');
    final group = _symbols.GROUP_SEP;
    if (group.isNotEmpty) cleaned = cleaned.replaceAll(group, '');
    final decimal = _symbols.DECIMAL_SEP;
    if (decimal != '.') cleaned = cleaned.replaceAll(decimal, '.');
    cleaned = cleaned.replaceAll(RegExp('[^0-9.]'), '');

    if (cleaned.isEmpty || '.'.allMatches(cleaned).length > 1) return null;
    if (cleaned.startsWith('.')) cleaned = '0$cleaned';
    if (cleaned.endsWith('.')) cleaned = cleaned.substring(0, cleaned.length - 1);

    return Money.tryParseDecimal(negative ? '-$cleaned' : cleaned, currency);
  }
}
