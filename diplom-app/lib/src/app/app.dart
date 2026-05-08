import 'package:diplom_app/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/pwa/clinova_web_install_bar.dart';
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
        final routed = child ?? const SizedBox.shrink();
        // Web: full-width Flutter view; only routed content is clamped/centered in Dart.
        final content = kIsWeb
            ? LayoutBuilder(
                builder: (context, constraints) {
                  final mq = MediaQuery.of(context);
                  final width = constraints.maxWidth.isFinite &&
                          constraints.maxWidth > 0
                      ? constraints.maxWidth
                      : mq.size.width;
                  // Desktop: use up to 1320px; never wider than the viewport.
                  final effectiveWidth = kIsWeb && width > 1200
                      ? (width > 1320 ? 1320.0 : width)
                      : width;
                  return ColoredBox(
                    color: const Color(0xFFF8FBFF),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: effectiveWidth),
                        child: MediaQuery(
                          data: mq.copyWith(
                            size: Size(effectiveWidth, mq.size.height),
                          ),
                          child: routed,
                        ),
                      ),
                    ),
                  );
                },
              )
            : routed;

        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: RealtimeConnectionScope(
                child: content,
              ),
            ),
            if (kIsWeb)
              const Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: ClinovaWebInstallBar(),
              ),
          ],
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
