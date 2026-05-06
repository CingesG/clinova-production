import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/context_l10n.dart';
import '../../../core/navigation/go_router_pop.dart';
import '../../../core/widgets/clinova_backdrop.dart';
import '../../../core/widgets/clinova_logo.dart';
import '../../auth/application/auth_controller.dart';

class DoctorChatLandingScreen extends ConsumerWidget {
  const DoctorChatLandingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final auth = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    const primary = Color(0xFF1769FF);
    const navy = Color(0xFF071B4D);

    return Scaffold(
      body: ClinovaBackdrop(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: () => popOrGo(
                        context,
                        clinovaNavigationFallback(
                          isAuthenticated: auth.isAuthenticated,
                          role: auth.user?.role,
                        ),
                      ),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: ClinovaLogo(
                        size: 36,
                        variant: LogoVariant.dark,
                        subtitle: 'AI Healthcare Platform',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.chatLandingTitle,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.chatLandingSubtitle,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF64748B),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  color: const Color(0xFFEFF6FF),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: Color(0xFFEA580C)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l10n.chatLandingSafety,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF0F172A),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (auth.isAuthenticated) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: () => context.push('/doctor-chat'),
                      child: Text(l10n.chatLandingStart),
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: () => context.push('/auth/login'),
                      child: Text(l10n.chatLandingLoginToChat),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: () => context.push('/auth/register'),
                      child: Text(l10n.profileCreateAccount),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    if (auth.isAuthenticated) {
                      context.push('/doctor-chat');
                    } else {
                      context.push('/auth/login');
                    }
                  },
                  child: Text(l10n.chatLandingViewOnline),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
