import 'package:coin_pilot/src/core/time/local_date.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'notification_service.g.dart';

/// Local notifications (bill reminders, budget alerts). Implemented with
/// `flutter_local_notifications` in roadmap phase 4; until then a no-op keeps
/// callers and tests simple.
abstract interface class NotificationService {
  Future<void> initialize();

  Future<void> scheduleBillReminder({
    required String id,
    required String title,
    required String body,
    required LocalDate dueOn,
  });

  Future<void> showBudgetAlert({required String id, required String title, required String body});

  Future<void> cancel(String id);
}

final class NoopNotificationService implements NotificationService {
  const NoopNotificationService();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> scheduleBillReminder({
    required String id,
    required String title,
    required String body,
    required LocalDate dueOn,
  }) async {}

  @override
  Future<void> showBudgetAlert({
    required String id,
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> cancel(String id) async {}
}

@Riverpod(keepAlive: true)
NotificationService notificationService(Ref ref) => const NoopNotificationService();
