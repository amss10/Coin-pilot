import 'package:clock/clock.dart';
import 'package:coin_pilot/src/core/database/converters/local_date_converter.dart';
import 'package:coin_pilot/src/core/database/seed/default_categories.dart';
import 'package:coin_pilot/src/core/database/tables/accounts.dart';
import 'package:coin_pilot/src/core/database/tables/ai.dart';
import 'package:coin_pilot/src/core/database/tables/budgets.dart';
import 'package:coin_pilot/src/core/database/tables/capture.dart';
import 'package:coin_pilot/src/core/database/tables/categories.dart';
import 'package:coin_pilot/src/core/database/tables/planning.dart';
import 'package:coin_pilot/src/core/database/tables/transactions.dart';
import 'package:coin_pilot/src/core/finance/enums.dart';
import 'package:coin_pilot/src/core/ids/id_generator.dart';
import 'package:coin_pilot/src/core/time/local_date.dart';
import 'package:coin_pilot/src/core/time/recurrence.dart';
import 'package:drift/drift.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Accounts,
    Categories,
    Transactions,
    TransactionSplits,
    Budgets,
    BudgetLines,
    BudgetLineLimits,
    RecurringRules,
    Goals,
    GoalContributions,
    Receipts,
    MerchantRules,
    ImportProfiles,
    ImportBatches,
    AiConversations,
    AiMessages,
    AiInsights,
    AppSettings,
  ],
  include: {'views/categorized_amounts.drift'},
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e, {IdGenerator? ids, Clock? clock})
    : ids = ids ?? UuidV7Generator(),
      clock = clock ?? const Clock();

  /// Id source used for seeded rows (injected for deterministic tests).
  final IdGenerator ids;
  final Clock clock;

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _seedDefaultCategories();
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _seedDefaultCategories() async {
    final now = clock.now().toUtc();
    final idsByKey = <String, String>{};
    await batch((batch) {
      var order = 0;
      for (final seed in defaultCategories) {
        final id = ids.newId();
        idsByKey[seed.key] = id;
        batch.insert(
          categories,
          CategoriesCompanion.insert(
            id: id,
            createdAt: now,
            updatedAt: now,
            kind: seed.kind,
            name: seed.name,
            parentId: Value(seed.parent == null ? null : idsByKey[seed.parent]),
            systemKey: Value(seed.key),
            iconKey: Value(seed.icon),
            color: Value(seed.color),
            sortOrder: Value(order++),
          ),
        );
      }
    });
  }
}
