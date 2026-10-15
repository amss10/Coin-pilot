import 'package:coin_pilot/src/core/finance/enums.dart';
import 'package:meta/meta.dart';

/// A seeded category. [key] becomes `system_key`; [parent] is the key of the
/// group it belongs to.
@immutable
final class SeedCategory {
  const SeedCategory(this.key, this.name, this.kind, {this.parent, this.icon, this.color});

  final String key;
  final String name;
  final CategoryKind kind;
  final String? parent;
  final String? icon;
  final int? color;
}

const _e = CategoryKind.expense;
const _i = CategoryKind.income;

/// Default categories created on first launch. Users can rename or archive them.
const List<SeedCategory> defaultCategories = [
  // Expense groups first, then their children.
  SeedCategory('housing', 'Housing', _e, icon: 'home', color: 0xFF6D4C41),
  SeedCategory('rent', 'Rent & mortgage', _e, parent: 'housing', icon: 'home'),
  SeedCategory('utilities', 'Utilities', _e, parent: 'housing', icon: 'bolt'),
  SeedCategory('internet_phone', 'Internet & phone', _e, parent: 'housing', icon: 'wifi'),
  SeedCategory('home_maintenance', 'Home maintenance', _e, parent: 'housing', icon: 'build'),

  SeedCategory('food', 'Food', _e, icon: 'restaurant', color: 0xFF2E7D32),
  SeedCategory('groceries', 'Groceries', _e, parent: 'food', icon: 'shopping_cart'),
  SeedCategory('dining_out', 'Dining out', _e, parent: 'food', icon: 'restaurant'),
  SeedCategory('coffee', 'Coffee & snacks', _e, parent: 'food', icon: 'coffee'),

  SeedCategory('transport', 'Transport', _e, icon: 'directions_car', color: 0xFF1565C0),
  SeedCategory('fuel', 'Fuel', _e, parent: 'transport', icon: 'local_gas_station'),
  SeedCategory('public_transport', 'Public transport', _e, parent: 'transport', icon: 'train'),
  SeedCategory('taxi', 'Taxi & rideshare', _e, parent: 'transport', icon: 'local_taxi'),
  SeedCategory('car_maintenance', 'Car maintenance', _e, parent: 'transport', icon: 'build'),
  SeedCategory('parking', 'Parking & tolls', _e, parent: 'transport', icon: 'local_parking'),

  SeedCategory('shopping', 'Shopping', _e, icon: 'shopping_bag', color: 0xFFAD1457),
  SeedCategory('clothing', 'Clothing', _e, parent: 'shopping', icon: 'checkroom'),
  SeedCategory('electronics', 'Electronics', _e, parent: 'shopping', icon: 'devices'),
  SeedCategory('household', 'Household items', _e, parent: 'shopping', icon: 'chair'),

  SeedCategory('health', 'Health', _e, icon: 'favorite', color: 0xFFC62828),
  SeedCategory('medical', 'Medical', _e, parent: 'health', icon: 'local_hospital'),
  SeedCategory('pharmacy', 'Pharmacy', _e, parent: 'health', icon: 'medication'),
  SeedCategory('fitness', 'Fitness', _e, parent: 'health', icon: 'fitness_center'),

  SeedCategory('entertainment', 'Entertainment', _e, icon: 'theaters', color: 0xFF6A1B9A),
  SeedCategory('subscriptions', 'Subscriptions', _e, parent: 'entertainment', icon: 'subscriptions'),
  SeedCategory('hobbies', 'Hobbies', _e, parent: 'entertainment', icon: 'palette'),
  SeedCategory('travel', 'Travel', _e, parent: 'entertainment', icon: 'flight'),

  SeedCategory('personal', 'Personal & family', _e, icon: 'people', color: 0xFFEF6C00),
  SeedCategory('personal_care', 'Personal care', _e, parent: 'personal', icon: 'spa'),
  SeedCategory('education', 'Education', _e, parent: 'personal', icon: 'school'),
  SeedCategory('kids', 'Kids', _e, parent: 'personal', icon: 'child_care'),
  SeedCategory('gifts_donations', 'Gifts & donations', _e, parent: 'personal', icon: 'redeem'),
  SeedCategory('pets', 'Pets', _e, parent: 'personal', icon: 'pets'),

  SeedCategory('financial', 'Financial', _e, icon: 'account_balance', color: 0xFF455A64),
  SeedCategory('fees', 'Fees & charges', _e, parent: 'financial', icon: 'receipt_long'),
  SeedCategory('insurance', 'Insurance', _e, parent: 'financial', icon: 'shield'),
  SeedCategory('taxes', 'Taxes', _e, parent: 'financial', icon: 'gavel'),
  SeedCategory('debt_payments', 'Debt payments', _e, parent: 'financial', icon: 'credit_card'),

  SeedCategory('other_expense', 'Other', _e, icon: 'more_horiz', color: 0xFF757575),

  // Income.
  SeedCategory('salary', 'Salary', _i, icon: 'payments', color: 0xFF00897B),
  SeedCategory('business', 'Business income', _i, icon: 'storefront', color: 0xFF00897B),
  SeedCategory('freelance', 'Freelance', _i, icon: 'work', color: 0xFF00897B),
  SeedCategory('investments', 'Investments', _i, icon: 'trending_up', color: 0xFF00897B),
  SeedCategory('gifts_received', 'Gifts received', _i, icon: 'card_giftcard', color: 0xFF00897B),
  SeedCategory('refunds', 'Refunds', _i, icon: 'undo', color: 0xFF00897B),
  SeedCategory('other_income', 'Other income', _i, icon: 'add_circle', color: 0xFF00897B),
];
