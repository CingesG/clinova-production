import 'package:diplom_app/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/auth_lifecycle_scope.dart';
import '../core/web/web_startup_loader.dart';
import '../core/pwa/clinova_web_install_bar.dart';
import '../core/network/realtime_connection_scope.dart';
import '../core/theme/clinova_theme.dart';
import '../features/settings/presentation/language_controller.dart';
import 'router.dart';

class ClinovaApp extends ConsumerStatefulWidget {
  const ClinovaApp({super.key});

  @override
  ConsumerState<ClinovaApp> createState() => _ClinovaAppState();
}

class _ClinovaAppState extends ConsumerState<ClinovaApp> {
  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        hideWebHtmlStartupLoader();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
              child: AuthLifecycleScope(
                child: RealtimeConnectionScope(
                  child: content,
                ),
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
