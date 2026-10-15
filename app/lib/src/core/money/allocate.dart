import 'package:coin_pilot/src/core/money/money.dart';

/// Splits [total] into parts proportional to [weights] so that the parts
/// always sum exactly to [total] (largest-remainder method).
///
/// Leftover minor units go to the parts with the largest remainders; ties go to
/// the earlier part. Weights must be non-negative and not all zero.
List<Money> allocate(Money total, List<int> weights) {
  if (weights.isEmpty) {
    throw ArgumentError.value(weights, 'weights', 'Must not be empty');
  }
  if (weights.any((w) => w < 0)) {
    throw ArgumentError.value(weights, 'weights', 'Must be non-negative');
  }
  final weightSum = weights.fold<int>(0, (sum, w) => sum + w);
  if (weightSum == 0) {
    throw ArgumentError.value(weights, 'weights', 'Must not all be zero');
  }

  final negative = total.isNegative;
  final amount = BigInt.from(total.minor.abs());
  final divisor = BigInt.from(weightSum);

  final shares = <int>[];
  final remainders = <BigInt>[];
  var allocated = 0;
  for (final weight in weights) {
    final product = amount * BigInt.from(weight);
    final share = (product ~/ divisor).toInt();
    shares.add(share);
    remainders.add(product.remainder(divisor));
    allocated += share;
  }

  var leftover = total.minor.abs() - allocated;
  final order = List<int>.generate(weights.length, (i) => i)
    ..sort((a, b) {
      final byRemainder = remainders[b].compareTo(remainders[a]);
      return byRemainder != 0 ? byRemainder : a.compareTo(b);
    });
  for (final index in order) {
    if (leftover == 0) break;
    shares[index] += 1;
    leftover -= 1;
  }

  return [
    for (final share in shares) Money(negative ? -share : share, total.currency),
  ];
}

/// Splits [total] into [parts] near-equal amounts that sum exactly to [total].
List<Money> splitEvenly(Money total, int parts) {
  if (parts <= 0) {
    throw ArgumentError.value(parts, 'parts', 'Must be positive');
  }
  return allocate(total, List<int>.filled(parts, 1));
}
