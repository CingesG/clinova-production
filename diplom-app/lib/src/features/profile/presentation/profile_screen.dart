import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/context_l10n.dart';
import '../../../core/navigation/go_router_pop.dart';
import '../../../core/widgets/clinova_backdrop.dart';
import '../../../core/widgets/clinova_circle_avatar.dart';
import '../../../core/widgets/clinova_logo.dart';
import '../../../core/widgets/premium_healthcare_shell.dart';
import '../../auth/application/auth_controller.dart';
import '../../pwa/application/clinova_pwa_bridge.dart';
import '../../pwa/presentation/install_app_banner.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;

    if (!authState.isAuthenticated || authState.user == null) {
      return Scaffold(
        body: ClinovaBackdrop(
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton.filledTonal(
                    onPressed: () => popOrGo(context, '/home'),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(height: 20),
                  const ClinovaLogo(
                    size: 58,
                    variant: LogoVariant.dark,
                  ),
                  const SizedBox(height: 28),
                  Text(
                    l10n.profileGuestTitle,
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.profileGuestSubtitle,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 28),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.97),
                      borderRadius: BorderRadius.circular(ClinovaPremium.radiusLg),
                      border: Border.all(
                        color: ClinovaPremium.border.withValues(alpha: 0.65),
                      ),
                      boxShadow: ClinovaPremium.cardShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton(
                          onPressed: () => context.push('/auth/login'),
                          child: Text(l10n.profileSignIn),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () => context.push('/auth/register'),
                          child: Text(l10n.profileCreateAccount),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final user = authState.user!;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => popOrGo(context, '/home'),
        ),
        title: Text(l10n.profileTitle),
      ),
      body: ClinovaBackdrop(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.97),
                borderRadius: BorderRadius.circular(ClinovaPremium.radiusLg),
                border: Border.all(
                  color: ClinovaPremium.border.withValues(alpha: 0.65),
                ),
                boxShadow: ClinovaPremium.cardShadow,
              ),
              child: Row(
                children: [
                  ClinovaCircleAvatar(
                    radius: 36,
                    initialsText: _initials(user.displayName),
                    backgroundColor: cs.primaryContainer,
                    foregroundColor: cs.onPrimaryContainer,
                    networkUrl: user.avatarUrl,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName,
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email,
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 6),
                        Chip(
                          label: Text(user.role),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: const Color(0xFFECFDF5),
                          side: BorderSide.none,
                          labelStyle: const TextStyle(
                            color: Color(0xFF047857),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => context.push('/profile/edit'),
                          child: Text(l10n.profileEditTitle),
                        ),
                        if (user.authProvider != 'GOOGLE') ...[
                          const SizedBox(height: 4),
                          TextButton.icon(
                            onPressed: () =>
                                context.push('/profile/change-password'),
                            icon: const Icon(Icons.lock_outline_rounded, size: 18),
                            label: Text(l10n.profileChangePasswordTitle),
                            style: TextButton.styleFrom(
                              alignment: Alignment.centerLeft,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (kIsWeb && !clinovaPwaIsStandalone()) ...[
              const SizedBox(height: 16),
              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: Icon(Icons.add_to_home_screen_rounded, color: cs.primary),
                  title: const Text('App суулгах'),
                  subtitle: const Text('Clinova-г Home screen дээр нэмэх заавар'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showClinovaPwaInstallSheet(
                    context,
                    ref: ref,
                    markDismissedOnLater: false,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.tune_rounded),
                    title: Text(l10n.settings),
                    subtitle: Text(l10n.profileSettingsSubtitle),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/settings'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.logout_rounded, color: cs.error),
                    title: Text(
                      l10n.logOut,
                      style: TextStyle(
                        color: cs.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () async {
                      await ref.read(authControllerProvider.notifier).logout();
                      if (context.mounted) context.go('/home');
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final s = parts.first;
      if (s.length >= 2) return s.substring(0, 2).toUpperCase();
      return s.toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}
