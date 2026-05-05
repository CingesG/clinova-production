import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/localization/context_l10n.dart';
import '../features/auth/application/auth_controller.dart';

/// Bottom navigation for authenticated **patients** on main app tabs only.
class PatientShell extends ConsumerWidget {
  const PatientShell({required this.child, super.key});

  final Widget child;

  static bool isDesktopLayout(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 900;

  static bool _shouldShowDock(String path, String? role) {
    if (role != 'PATIENT') return false;
    if (path == '/home' ||
        path == '/profile' ||
        path.startsWith('/profile/')) {
      return true;
    }
    if (path == '/appointments' || path.startsWith('/appointments/')) {
      return true;
    }
    if (path == '/doctor-chat' || path.startsWith('/doctor-chat/')) {
      return true;
    }
    return false;
  }

  static int _indexForPath(String path) {
    if (path.startsWith('/appointments')) return 1;
    if (path.startsWith('/doctor-chat')) return 2;
    if (path.startsWith('/profile')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final path = GoRouterState.of(context).uri.path;
    final role = auth.user?.role;

    if (!auth.isAuthenticated || !_shouldShowDock(path, role)) {
      return child;
    }

    if (isDesktopLayout(context)) {
      return child;
    }

    final l10n = context.l10n;
    final idx = _indexForPath(path);
    const primary = Color(0xFF1769FF);

    return Scaffold(
      body: child,
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: Material(
          elevation: 8,
          shadowColor: const Color(0x140F172A),
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: _DockItem(
                    icon: Icons.home_rounded,
                    label: l10n.homeDockHome,
                    selected: idx == 0,
                    primary: primary,
                    onTap: () => context.go('/home'),
                  ),
                ),
                Expanded(
                  child: _DockItem(
                    icon: Icons.calendar_month_rounded,
                    label: l10n.homeDockBook,
                    selected: idx == 1,
                    primary: primary,
                    onTap: () => context.go('/appointments'),
                  ),
                ),
                Expanded(
                  child: _DockItem(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: l10n.homeCardLiveChatTitle,
                    selected: idx == 2,
                    primary: primary,
                    onTap: () => context.go('/doctor-chat'),
                  ),
                ),
                Expanded(
                  child: _DockItem(
                    icon: Icons.person_outline_rounded,
                    label: l10n.homeDockProfile,
                    selected: idx == 3,
                    primary: primary,
                    onTap: () => context.go('/profile'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  const _DockItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.primary,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? primary : const Color(0xFF64748B);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
