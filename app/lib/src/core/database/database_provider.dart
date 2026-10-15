import 'package:coin_pilot/src/core/database/app_database.dart';
import 'package:coin_pilot/src/core/database/connection.dart';
import 'package:coin_pilot/src/core/ids/id_generator.dart';
import 'package:coin_pilot/src/core/time/clock_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'database_provider.g.dart';

/// The single app database. `bootstrap.dart` overrides this with an instance it
/// already opened (to read settings before the first frame); tests override it
/// with an in-memory database.
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase(
    openAppDatabaseConnection(),
    ids: ref.watch(idGeneratorProvider),
    clock: ref.watch(appClockProvider),
  );
  ref.onDispose(db.close);
  return db;
}
