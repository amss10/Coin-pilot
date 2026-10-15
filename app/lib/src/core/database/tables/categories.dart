import 'package:coin_pilot/src/core/database/tables/sync_columns.dart';
import 'package:coin_pilot/src/core/finance/enums.dart';
import 'package:drift/drift.dart';

/// Two-level categories (group → category).
@DataClassName('CategoryRow')
@TableIndex.sql(
  'CREATE INDEX idx_categories_parent ON categories (parent_id) WHERE deleted_at IS NULL',
)
class Categories extends Table with SyncColumns {
  /// Parent group id; null for top-level groups and stand-alone categories.
  TextColumn get parentId => text().nullable()();
  TextColumn get kind => textEnum<CategoryKind>()();
  TextColumn get name => text().withLength(min: 1, max: 40)();

  /// Stable key of seeded categories (e.g. `groceries`) so their names stay
  /// translatable until the user renames them.
  TextColumn get systemKey => text().nullable()();
  TextColumn get iconKey => text().nullable()();

  /// ARGB colour.
  IntColumn get color => integer().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}
