import 'package:material_ui/material_ui.dart';

/// Spacing scale (logical pixels).
abstract final class AppSpacing {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

abstract final class AppRadii {
  static const double card = 16;
  static const double field = 12;
  static const double chip = 8;
}

abstract final class AppColors {
  /// Brand seed: a calm teal ("autopilot" instrument green).
  static const Color seed = Color(0xFF0F766E);
}

/// Semantic colours for money that the Material scheme doesn't provide.
@immutable
class FinanceColors extends ThemeExtension<FinanceColors> {
  const FinanceColors({
    required this.income,
    required this.expense,
    required this.warning,
    required this.positive,
  });

  static const light = FinanceColors(
    income: Color(0xFF15803D),
    expense: Color(0xFFB42318),
    warning: Color(0xFFB54708),
    positive: Color(0xFF0F766E),
  );

  static const dark = FinanceColors(
    income: Color(0xFF6CE9A6),
    expense: Color(0xFFFDA29B),
    warning: Color(0xFFFEC84B),
    positive: Color(0xFF5EEAD4),
  );

  final Color income;
  final Color expense;
  final Color warning;
  final Color positive;

  @override
  FinanceColors copyWith({Color? income, Color? expense, Color? warning, Color? positive}) =>
      FinanceColors(
        income: income ?? this.income,
        expense: expense ?? this.expense,
        warning: warning ?? this.warning,
        positive: positive ?? this.positive,
      );

  @override
  FinanceColors lerp(FinanceColors? other, double t) {
    if (other == null) return this;
    return FinanceColors(
      income: Color.lerp(income, other.income, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      positive: Color.lerp(positive, other.positive, t)!,
    );
  }
}

extension FinanceColorsX on BuildContext {
  FinanceColors get financeColors => Theme.of(this).extension<FinanceColors>() ?? FinanceColors.light;
}
