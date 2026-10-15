import 'package:coin_pilot/src/core/money/currency.dart';
import 'package:meta/meta.dart';

/// An exact amount of money: integer minor units plus a [Currency].
///
/// Money is never stored or computed as a `double` (see ADR 0004). Doubles are
/// only used when formatting for display.
@immutable
final class Money implements Comparable<Money> {
  const Money(this.minor, this.currency);

  factory Money.zero(Currency currency) => Money(0, currency);

  /// Parses a plain decimal string such as `-45.30`, `1200` or `+0.5` exactly.
  ///
  /// No grouping separators or symbols are accepted (that is the job of
  /// `MoneyInputParser`). Extra fraction digits are allowed only if they are
  /// zeros. Throws [FormatException] on invalid input.
  factory Money.parseDecimal(String input, Currency currency) {
    final match = _decimalPattern.firstMatch(input.trim());
    if (match == null) {
      throw FormatException('Not a decimal amount', input);
    }
    final negative = match.group(1) == '-';
    final whole = match.group(2)!;
    var fraction = match.group(3) ?? '';
    if (fraction.length > currency.decimals) {
      final extra = fraction.substring(currency.decimals);
      if (extra.replaceAll('0', '').isNotEmpty) {
        throw FormatException(
          'Too many decimals for ${currency.code} (max ${currency.decimals})',
          input,
        );
      }
      fraction = fraction.substring(0, currency.decimals);
    }
    if (whole.replaceFirst(RegExp('^0+'), '').length > _maxWholeDigits) {
      throw FormatException('Amount too large', input);
    }
    final padded = fraction.padRight(currency.decimals, '0');
    final minor = int.parse('$whole$padded');
    return Money(negative ? -minor : minor, currency);
  }

  /// Like [Money.parseDecimal] but returns null instead of throwing.
  static Money? tryParseDecimal(String? input, Currency currency) {
    if (input == null) return null;
    try {
      return Money.parseDecimal(input, currency);
    } on FormatException {
      return null;
    }
  }

  static final RegExp _decimalPattern = RegExp(r'^([+-])?(\d+)(?:\.(\d+))?$');
  static const int _maxWholeDigits = 15;

  /// Signed amount in minor units (cents for USD). Negative means money out.
  final int minor;
  final Currency currency;

  bool get isZero => minor == 0;
  bool get isNegative => minor < 0;
  bool get isPositive => minor > 0;

  Money abs() => isNegative ? -this : this;

  Money operator -() => Money(-minor, currency);

  Money operator +(Money other) {
    _assertSameCurrency(other);
    return Money(minor + other.minor, currency);
  }

  Money operator -(Money other) {
    _assertSameCurrency(other);
    return Money(minor - other.minor, currency);
  }

  Money operator *(int factor) => Money(minor * factor, currency);

  bool operator <(Money other) => compareTo(other) < 0;
  bool operator <=(Money other) => compareTo(other) <= 0;
  bool operator >(Money other) => compareTo(other) > 0;
  bool operator >=(Money other) => compareTo(other) >= 0;

  @override
  int compareTo(Money other) {
    _assertSameCurrency(other);
    return minor.compareTo(other.minor);
  }

  /// Decimal string with exactly `currency.decimals` fraction digits and no
  /// grouping, e.g. `-45.30` or `1200` (JPY). This is the AI wire format.
  String toDecimalString() {
    final digits = minor.abs().toString();
    final sign = isNegative ? '-' : '';
    if (currency.decimals == 0) return '$sign$digits';
    final padded = digits.padLeft(currency.decimals + 1, '0');
    final split = padded.length - currency.decimals;
    return '$sign${padded.substring(0, split)}.${padded.substring(split)}';
  }

  /// Major-unit value for display formatting only. Never use for arithmetic.
  double toDisplayDouble() => minor / currency.minorPerMajor;

  void _assertSameCurrency(Money other) {
    if (other.currency != currency) {
      throw ArgumentError('Currency mismatch: ${currency.code} vs ${other.currency.code}');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is Money && other.minor == minor && other.currency == currency;

  @override
  int get hashCode => Object.hash(minor, currency);

  @override
  String toString() => '${toDecimalString()} ${currency.code}';
}
