import 'package:diplom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/realtime_connection_scope.dart';
import '../core/theme/clinova_theme.dart';
import '../features/settings/presentation/language_controller.dart';
import 'router.dart';

class ClinovaApp extends ConsumerWidget {
  const ClinovaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(languageControllerProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      builder: (context, child) {
        return RealtimeConnectionScope(
          child: child ?? const SizedBox.shrink(),
        );
      },
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: ClinovaTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
    );
  }
}
