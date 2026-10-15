/// Base type for expected, user-explainable failures. Unexpected errors
/// (bugs) are left as plain exceptions and reported to crash reporting.
abstract class AppFailure implements Exception {
  const AppFailure(this.message);

  /// Developer-facing description. User-facing text comes from l10n.
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Input broke a business rule (e.g. splits don't add up).
final class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message, {this.code});

  /// Machine-readable reason, e.g. `split_sum_mismatch`.
  final String? code;
}

/// A record that should exist was not found.
final class NotFoundFailure extends AppFailure {
  const NotFoundFailure(super.message);
}

/// Reading or writing local storage failed.
final class StorageFailure extends AppFailure {
  const StorageFailure(super.message, {this.cause});

  final Object? cause;
}
