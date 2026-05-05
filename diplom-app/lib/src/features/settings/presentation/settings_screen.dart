import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/context_l10n.dart';
import '../../../core/navigation/go_router_pop.dart';
import '../../../core/widgets/clinova_backdrop.dart';
import '../../pwa/presentation/install_app_banner.dart';
import 'language_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final currentLocale = ref.watch(languageControllerProvider);
    final langCode =
        currentLocale.languageCode == 'en' || currentLocale.languageCode == 'mn'
            ? currentLocale.languageCode
            : 'mn';

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => popOrGo(context, '/home'),
        ),
      ),
      body: ClinovaBackdrop(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            Text(
              l10n.settingsSectionAccount,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            _SettingsCard(
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
            _SettingsCard(
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
            const SizedBox(height: 24),
            const PwaSettingsInstallCard(),
            Text(
              l10n.settingsSectionLanguage,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            _SettingsCard(
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
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.85),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x100F172A),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}
