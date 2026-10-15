import 'package:coin_pilot/src/core/errors/app_failure.dart';

/// App error codes from `docs/ai-contract.md`, plus client-side ones.
enum AiErrorCode {
  quotaExceeded('quota_exceeded'),
  rateLimited('rate_limited'),
  refusal('refusal'),
  invalidInput('invalid_input'),
  upstreamUnavailable('upstream_unavailable'),
  promptVersionRetired('prompt_version_retired'),
  conversationTooLong('conversation_too_long'),
  upgradeRequired('upgrade_required'),
  unauthenticated('unauthenticated'),

  /// The device could not reach the proxy (client-side).
  network('network'),
  internal('internal');

  const AiErrorCode(this.wire);

  final String wire;

  static AiErrorCode fromWire(String? code) =>
      values.firstWhere((value) => value.wire == code, orElse: () => AiErrorCode.internal);

  /// Whether retrying (after a back-off) can succeed.
  bool get isRetryable =>
      this == rateLimited || this == upstreamUnavailable || this == network;
}

/// A failed AI request. Never retried automatically by Riverpod (see
/// `retry_policy.dart`); the UI decides whether to offer a retry.
final class AiFailure extends AppFailure {
  const AiFailure(this.code, {String message = '', this.retryAfter, this.resetsAt})
    : super(message);

  /// Builds a failure from the `details` map of a callable error or the body of
  /// an HTTP/SSE error.
  factory AiFailure.fromDetails(Object? details, {String? fallbackMessage}) {
    if (details is Map) {
      final retryAfterMs = details['retryAfterMs'];
      return AiFailure(
        AiErrorCode.fromWire(details['code']?.toString()),
        message: details['message']?.toString() ?? fallbackMessage ?? '',
        retryAfter: retryAfterMs is num ? Duration(milliseconds: retryAfterMs.toInt()) : null,
        resetsAt: DateTime.tryParse(details['resetsAt']?.toString() ?? ''),
      );
    }
    return AiFailure(AiErrorCode.internal, message: fallbackMessage ?? '');
  }

  final AiErrorCode code;
  final Duration? retryAfter;
  final DateTime? resetsAt;

  @override
  String toString() => 'AiFailure(${code.wire}${message.isEmpty ? '' : ': $message'})';
}
