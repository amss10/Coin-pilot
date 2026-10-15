import 'package:coin_pilot/src/core/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart';

export 'package:coin_pilot/src/core/l10n/gen/app_localizations.dart';

extension AppLocalizationsX on BuildContext {
  /// Shorthand for `AppLocalizations.of(context)`.
  AppLocalizations get l10n => AppLocalizations.of(this);
}
