import 'package:meta/meta.dart';

/// An ISO-4217 currency and the number of decimals its minor unit uses.
@immutable
final class Currency {
  const Currency._(this.code, this.decimals);

  /// Looks up [code] (case-insensitive). Unknown but well-formed codes default
  /// to 2 decimals. Throws [ArgumentError] for malformed codes.
  factory Currency.of(String code) {
    final upper = code.trim().toUpperCase();
    if (!_codePattern.hasMatch(upper)) {
      throw ArgumentError.value(code, 'code', 'Not an ISO-4217 currency code');
    }
    return Currency._(upper, _decimalsByCode[upper] ?? 2);
  }

  /// Returns null instead of throwing for malformed codes.
  static Currency? tryOf(String? code) {
    if (code == null || !_codePattern.hasMatch(code.trim().toUpperCase())) {
      return null;
    }
    return Currency.of(code);
  }

  static const Currency usd = Currency._('USD', 2);

  /// Upper-case three-letter ISO-4217 code, e.g. `USD`.
  final String code;

  /// Number of minor-unit digits (JPY 0, USD 2, KWD 3).
  final int decimals;

  /// How many minor units make one major unit (10^decimals).
  int get minorPerMajor {
    var result = 1;
    for (var i = 0; i < decimals; i++) {
      result *= 10;
    }
    return result;
  }

  /// Currencies offered first in pickers; any valid ISO code is accepted.
  static const List<String> common = [
    'USD', 'EUR', 'GBP', 'EGP', 'SAR', 'AED', 'KWD', 'QAR', 'BHD', 'OMR', //
    'JOD', 'MAD', 'TND', 'TRY', 'INR', 'PKR', 'NGN', 'KES', 'ZAR', 'JPY', //
    'CNY', 'CAD', 'AUD', 'CHF', 'SEK', 'NOK', 'DKK', 'BRL', 'MXN', 'IDR', //
  ];

  static final RegExp _codePattern = RegExp(r'^[A-Z]{3}$');

  /// ISO-4217 currencies whose minor unit is not 2 decimals.
  static const Map<String, int> _decimalsByCode = {
    'BIF': 0, 'CLP': 0, 'DJF': 0, 'GNF': 0, 'ISK': 0, 'JPY': 0, 'KMF': 0, //
    'KRW': 0, 'PYG': 0, 'RWF': 0, 'UGX': 0, 'UYI': 0, 'VND': 0, 'VUV': 0, //
    'XAF': 0, 'XOF': 0, 'XPF': 0, //
    'BHD': 3, 'IQD': 3, 'JOD': 3, 'KWD': 3, 'LYD': 3, 'OMR': 3, 'TND': 3, //
    'CLF': 4, 'UYW': 4, //
  };

  @override
  bool operator ==(Object other) => other is Currency && other.code == code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => code;
}
