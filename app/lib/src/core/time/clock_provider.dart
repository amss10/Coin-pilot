import 'package:clock/clock.dart';
import 'package:coin_pilot/src/core/time/local_date.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'clock_provider.g.dart';

/// The app-wide clock. Tests override it with `Clock.fixed(...)`.
@Riverpod(keepAlive: true)
Clock appClock(Ref ref) => const Clock();

/// The device time zone (IANA id such as `Africa/Cairo`), detected at startup
/// and injected by `bootstrap.dart`. Defaults to `UTC` in tests.
@Riverpod(keepAlive: true)
String deviceTimeZone(Ref ref) => 'UTC';

extension ClockToday on Clock {
  /// Today's calendar date in the device's local time zone.
  LocalDate today() => LocalDate.fromDateTime(now());
}
