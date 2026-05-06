import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/context_l10n.dart';
import '../../../core/widgets/clinova_backdrop.dart';
import '../../../core/widgets/premium_healthcare_shell.dart';
import '../../auth/application/auth_controller.dart';
import '../../pwa/presentation/install_app_banner.dart';
import 'language_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static String _fallbackHome(String? role) {
    switch (role) {
      case 'ADMIN':
      case 'STAFF':
        return '/admin';
      case 'DOCTOR':
        return '/doctor';
      default:
        return '/home';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final currentLocale = ref.watch(languageControllerProvider);
    final user = ref.watch(authControllerProvider).user;
    final canSetPassword = user?.authProvider != 'GOOGLE';
    final langCode =
        currentLocale.languageCode == 'en' || currentLocale.languageCode == 'mn'
            ? currentLocale.languageCode
            : 'mn';

    return Scaffold(
      backgroundColor: ClinovaPremium.surfaceTint,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: ClinovaPremium.surfaceTint,
        surfaceTintColor: Colors.transparent,
        title: Text(
          l10n.settings,
          style: const TextStyle(
            color: ClinovaPremium.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: const IconThemeData(color: ClinovaPremium.textPrimary),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            final router = GoRouter.of(context);
            if (router.canPop()) {
              router.pop();
              return;
            }
            router.go(_fallbackHome(user?.role));
          },
        ),
      ),
      body: ClinovaBackdrop(
        child: PremiumPageCanvas(
          maxWidth: 720,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
            children: [
              PremiumSectionLabel(text: l10n.settingsSectionAccount),
              PremiumSettingsSurface(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.person_outline_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(l10n.settingsProfileTitle),
                  subtitle: Text(l10n.settingsProfileSubtitle),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/profile'),
                ),
              ),
              const SizedBox(height: 14),
              PremiumSettingsSurface(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.badge_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(l10n.settingsProfileEditTitle),
                  subtitle: Text(l10n.settingsProfileEditSubtitle),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/profile/edit'),
                ),
              ),
              if (canSetPassword) ...[
                const SizedBox(height: 14),
                PremiumSettingsSurface(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.lock_outline_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    title: Text(l10n.profileChangePasswordTitle),
                    subtitle: Text(l10n.profileChangePasswordSubtitle),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/profile/change-password'),
                  ),
                ),
              ],
              const SizedBox(height: 28),
              const PwaSettingsInstallCard(),
              PremiumSectionLabel(text: l10n.settingsSectionLanguage),
              PremiumSettingsSurface(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.language),
                  subtitle: Text(
                    langCode == 'mn'
                        ? l10n.languageMongolian
                        : l10n.languageEnglish,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'mn',
                    label: Text(l10n.languageMongolian),
                  ),
                  ButtonSegment(
                    value: 'en',
                    label: Text(l10n.languageEnglish),
                  ),
                ],
                selected: {langCode},
                onSelectionChanged: (selection) {
                  ref
                      .read(languageControllerProvider.notifier)
                      .setLanguage(selection.first);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
