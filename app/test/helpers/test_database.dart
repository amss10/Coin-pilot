import 'package:clock/clock.dart';
import 'package:coin_pilot/src/core/database/app_database.dart';
import 'package:coin_pilot/src/core/ids/id_generator.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';

/// The fixed "now" used across tests: 2026-10-15 09:00 UTC.
final DateTime testNow = DateTime.utc(2026, 10, 15, 9);

/// Opens a fresh in-memory database (default categories are seeded).
AppDatabase createTestDatabase({Clock? clock, IdGenerator? ids}) => AppDatabase(
  DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
  ids: ids ?? SequentialIdGenerator(prefix: 'seed'),
  clock: clock ?? Clock.fixed(testNow),
);
