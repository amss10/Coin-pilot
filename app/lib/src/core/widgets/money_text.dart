import 'dart:ui' show FontFeature;

import 'package:coin_pilot/src/core/money/money.dart';
import 'package:coin_pilot/src/core/money/money_format.dart';
import 'package:coin_pilot/src/core/theme/tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Displays [Money] formatted for the current locale with tabular figures so
/// columns of amounts line up.
class MoneyText extends StatelessWidget {
  const MoneyText(
    this.money, {
    this.style,
    this.colorize = false,
    this.showPlusSign = false,
    super.key,
  });

  final Money money;
  final TextStyle? style;

  /// Colours income green and spending red.
  final bool colorize;
  final bool showPlusSign;

  static final Map<String, MoneyFormatter> _formatters = {};

  static MoneyFormatter formatterFor(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return _formatters.putIfAbsent(locale, () => MoneyFormatter(locale));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.financeColors;
    final color = !colorize || money.isZero
        ? null
        : money.isNegative
        ? colors.expense
        : colors.income;
    final base = style ?? DefaultTextStyle.of(context).style;
    return Text(
      formatterFor(context).format(money, showPlusSign: showPlusSign),
      style: base.copyWith(
        color: color ?? base.color,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
