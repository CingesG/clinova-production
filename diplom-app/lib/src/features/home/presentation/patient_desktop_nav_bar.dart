import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/context_l10n.dart';
import '../../../core/widgets/clinova_logo.dart';

/// Top navigation for patient flows on wide screens (no bottom dock).
class PatientDesktopNavBar extends StatelessWidget {
  const PatientDesktopNavBar({
    super.key,
    required this.isAuthenticated,
    required this.onScrollToDoctors,
  });

  final bool isAuthenticated;
  final VoidCallback onScrollToDoctors;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final path = GoRouterState.of(context).uri.path;
    final primary = const Color(0xFF1769FF);
    final subtle = const Color(0xFF64748B);

    Widget navLink({
      required String label,
      required bool active,
      required VoidCallback onTap,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: active ? primary : subtle,
            backgroundColor:
                active ? primary.withValues(alpha: 0.1) : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: TextStyle(
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              fontSize: 14,
            ),
          ),
          child: Text(label),
        ),
      );
    }

    return Material(
      color: Colors.white.withValues(alpha: 0.94),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: const Color(0xFFE2E8F0).withValues(alpha: 0.95)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            InkWell(
              onTap: () => context.go('/home'),
              borderRadius: BorderRadius.circular(12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ClinovaLogo(size: 42, variant: LogoVariant.dark, showText: false),
                  const SizedBox(width: 8),
                  Text(
                    'Clinova',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF102A43),
                          letterSpacing: -0.4,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 0,
                runSpacing: 0,
                children: [
                  navLink(
                    label: l10n.homeNavHome,
                    active: path == '/home',
                    onTap: () => context.go('/home'),
                  ),
                  navLink(
                    label: l10n.homeNavServices,
                    active: path == '/chat-landing' ||
                        path == '/doctor-chat' ||
                        path.startsWith('/doctor-chat/'),
                    onTap: () => context.go('/chat-landing'),
                  ),
                  navLink(
                    label: l10n.homeNavDoctors,
                    active: false,
                    onTap: onScrollToDoctors,
                  ),
                  navLink(
                    label: l10n.homeNavAi,
                    active: path.startsWith('/agent'),
                    onTap: () => context.push('/agent'),
                  ),
                  navLink(
                    label: l10n.homeNavBook,
                    active: path.startsWith('/appointments') &&
                        !path.startsWith('/appointments-landing'),
                    onTap: () => context.go('/appointments'),
                  ),
                ],
              ),
            ),
            if (isAuthenticated) ...[
              FilledButton.tonalIcon(
                onPressed: () => context.push('/profile'),
                icon: const Icon(Icons.person_outline_rounded, size: 20),
                label: Text(l10n.homeNavProfile),
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ] else
              FilledButton(
                onPressed: () => context.push('/auth/login'),
                style: FilledButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(l10n.homeNavLogin),
              ),
          ],
        ),
      ),
    );
  }
}

/// Centers patient home content on wide layouts.
class PatientDesktopContainer extends StatelessWidget {
  const PatientDesktopContainer({super.key, required this.child});

  final Widget child;

  static const double maxWidth = 1280;

  static bool isDesktopWidth(double width) => width >= 900;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w < 900) return child;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
