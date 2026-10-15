import 'package:coin_pilot/src/core/database/app_database.dart';
import 'package:coin_pilot/src/core/database/seed/default_categories.dart';
import 'package:coin_pilot/src/core/finance/enums.dart';
import 'package:coin_pilot/src/core/time/local_date.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  test('seeds every default category once, with parents resolved', () async {
    final rows = await db.select(db.categories).get();
    expect(rows, hasLength(defaultCategories.length));

    final byKey = {for (final row in rows) row.systemKey: row};
    expect(byKey['groceries']!.parentId, byKey['food']!.id);
    expect(byKey['food']!.parentId, isNull);
    expect(byKey['salary']!.kind, CategoryKind.income);
  });

  test('foreign keys are enforced', () async {
    final insert = db.into(db.transactions).insert(
      TransactionsCompanion.insert(
        id: 'tx-1',
        createdAt: testNow,
        updatedAt: testNow,
        accountId: 'missing-account',
        bookedOn: LocalDate(2026, 10, 1),
        amountMinor: -100,
        currencyCode: 'USD',
        entryType: EntryType.standard,
        categorySource: CategorySource.none,
        source: TransactionSource.manual,
      ),
    );
    await expectLater(insert, throwsA(isA<Exception>()));
  });

  group('categorized_amounts view', () {
    late String groceries;
    late String dining;

    setUp(() async {
      final categories = await db.select(db.categories).get();
      groceries = categories.firstWhere((c) => c.systemKey == 'groceries').id;
      dining = categories.firstWhere((c) => c.systemKey == 'dining_out').id;

      await db.into(db.accounts).insert(
        AccountsCompanion.insert(
          id: 'acc-1',
          createdAt: testNow,
          updatedAt: testNow,
          name: 'Visa',
          type: AccountType.creditCard,
          currencyCode: 'USD',
        ),
      );

      Future<void> tx(
        String id,
        int amount, {
        String? category,
        EntryType type = EntryType.standard,
        DateTime? deletedAt,
      }) => db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          id: id,
          createdAt: testNow,
          updatedAt: testNow,
          deletedAt: Value(deletedAt),
          accountId: 'acc-1',
          bookedOn: LocalDate(2026, 10, 3),
          amountMinor: amount,
          currencyCode: 'USD',
          entryType: type,
          categoryId: Value(category),
          categorySource: CategorySource.user,
          source: TransactionSource.manual,
        ),
      );

      await tx('plain', -1000, category: groceries);
      await tx('split-parent', -3000);
      await tx('transfer-leg', -5000, type: EntryType.transfer);
      await tx('opening', 20000, type: EntryType.openingBalance);
      await tx('deleted', -700, category: dining, deletedAt: testNow);

      for (final (id, category, amount) in [
        ('s1', groceries, -1200),
        ('s2', dining, -1800),
      ]) {
        await db.into(db.transactionSplits).insert(
          TransactionSplitsCompanion.insert(
            id: id,
            createdAt: testNow,
            updatedAt: testNow,
            transactionId: 'split-parent',
            categoryId: category,
            amountMinor: amount,
            categorySource: CategorySource.user,
          ),
        );
      }
    });

    test('includes unsplit rows and split lines, excludes transfers and deleted rows', () async {
      final rows = await db.select(db.categorizedAmounts).get();
      final summary = {
        for (final row in rows) row.splitId ?? row.transactionId: (row.categoryId, row.amountMinor),
      };

      expect(summary, {
        'plain': (groceries, -1000),
        's1': (groceries, -1200),
        's2': (dining, -1800),
      });
      expect(rows.first.bookedOn, LocalDate(2026, 10, 3));
    });
  });
}
