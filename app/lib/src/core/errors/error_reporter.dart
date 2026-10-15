import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Where unexpected errors go. Crashlytics only when Firebase is configured and
/// the user opted in (settings); otherwise the debug console.
abstract interface class ErrorReporter {
  void record(Object error, StackTrace? stack, {bool fatal = false});
}

final class DebugErrorReporter implements ErrorReporter {
  const DebugErrorReporter();

  @override
  void record(Object error, StackTrace? stack, {bool fatal = false}) {
    debugPrint('${fatal ? 'FATAL' : 'Error'}: $error\n$stack');
  }
}

final class CrashlyticsErrorReporter implements ErrorReporter {
  const CrashlyticsErrorReporter();

  @override
  void record(Object error, StackTrace? stack, {bool fatal = false}) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: fatal);
  }
}
