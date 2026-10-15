import 'dart:async';
import 'dart:io';

import 'package:coin_pilot/src/core/errors/app_failure.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global Riverpod retry policy (passed to `ProviderScope(retry:)`).
///
/// Riverpod 3 retries every failing provider by default. That would silently
/// replay paid AI calls and hammer a broken database, so we only retry
/// transient I/O problems, at most twice, and never [AppFailure]s.
Duration? appRetryPolicy(int retryCount, Object error) {
  final cause = error is ProviderException ? error.exception : error;
  if (cause is AppFailure) return null;
  if (retryCount >= 2) return null;
  if (cause is TimeoutException || cause is IOException) {
    return Duration(milliseconds: 400 * (1 << retryCount));
  }
  return null;
}
