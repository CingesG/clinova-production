import 'package:diplom_app/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';

extension ContextL10n on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
