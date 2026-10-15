import 'package:coin_pilot/src/core/l10n/l10n.dart';
import 'package:coin_pilot/src/core/money/currency.dart';
import 'package:coin_pilot/src/core/money/money_parser.dart';
import 'package:material_ui/material_ui.dart';

/// Text field for a positive amount in [currency]. Validation parses the text
/// exactly (no floating point) and rejects zero.
class AmountField extends StatelessWidget {
  const AmountField({
    required this.controller,
    required this.currency,
    this.autofocus = false,
    super.key,
  });

  final TextEditingController controller;
  final Currency currency;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final parser = MoneyInputParser(Localizations.localeOf(context).toLanguageTag());
    return TextFormField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: TextInputType.numberWithOptions(decimal: currency.decimals > 0),
      textInputAction: TextInputAction.next,
      style: Theme.of(context).textTheme.headlineSmall,
      decoration: InputDecoration(labelText: l10n.fieldAmount, suffixText: currency.code),
      validator: (text) {
        if (text == null || text.trim().isEmpty) return l10n.validationAmountRequired;
        final money = parser.parse(text, currency);
        if (money == null || money.isNegative) return l10n.validationAmountInvalid;
        if (money.isZero) return l10n.validationAmountZero;
        return null;
      },
    );
  }
}
