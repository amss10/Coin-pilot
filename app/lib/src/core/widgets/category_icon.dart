import 'package:material_ui/material_ui.dart';

/// Round icon for a category, account or transaction row.
class CategoryIcon extends StatelessWidget {
  const CategoryIcon({this.iconKey, this.color, this.size = 40, super.key});

  final String? iconKey;

  /// ARGB colour; falls back to the theme's secondary container.
  final int? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = color == null ? scheme.secondary : Color(color!);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: base.withValues(alpha: 0.15), shape: BoxShape.circle),
      child: Icon(iconForKey(iconKey), size: size * 0.5, color: base),
    );
  }

  /// Maps stored icon keys (see the category seed) to Material icons.
  static IconData iconForKey(String? key) => _icons[key] ?? Icons.label_outline;

  static const Map<String, IconData> _icons = {
    'home': Icons.home_outlined,
    'bolt': Icons.bolt_outlined,
    'wifi': Icons.wifi,
    'build': Icons.build_outlined,
    'restaurant': Icons.restaurant,
    'shopping_cart': Icons.shopping_cart_outlined,
    'coffee': Icons.coffee_outlined,
    'directions_car': Icons.directions_car_outlined,
    'local_gas_station': Icons.local_gas_station_outlined,
    'train': Icons.train_outlined,
    'local_taxi': Icons.local_taxi_outlined,
    'local_parking': Icons.local_parking,
    'shopping_bag': Icons.shopping_bag_outlined,
    'checkroom': Icons.checkroom,
    'devices': Icons.devices_outlined,
    'chair': Icons.chair_outlined,
    'favorite': Icons.favorite_outline,
    'local_hospital': Icons.local_hospital_outlined,
    'medication': Icons.medication_outlined,
    'fitness_center': Icons.fitness_center,
    'theaters': Icons.theaters_outlined,
    'subscriptions': Icons.subscriptions_outlined,
    'palette': Icons.palette_outlined,
    'flight': Icons.flight,
    'people': Icons.people_outline,
    'spa': Icons.spa_outlined,
    'school': Icons.school_outlined,
    'child_care': Icons.child_care,
    'redeem': Icons.redeem,
    'pets': Icons.pets,
    'account_balance': Icons.account_balance_outlined,
    'receipt_long': Icons.receipt_long_outlined,
    'shield': Icons.shield_outlined,
    'gavel': Icons.gavel,
    'credit_card': Icons.credit_card,
    'more_horiz': Icons.more_horiz,
    'payments': Icons.payments_outlined,
    'storefront': Icons.storefront_outlined,
    'work': Icons.work_outline,
    'trending_up': Icons.trending_up,
    'card_giftcard': Icons.card_giftcard,
    'undo': Icons.undo,
    'add_circle': Icons.add_circle_outline,
    'wallet': Icons.account_balance_wallet_outlined,
    'savings': Icons.savings_outlined,
    'swap': Icons.swap_horiz,
  };
}
