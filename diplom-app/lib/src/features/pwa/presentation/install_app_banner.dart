import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/clinova_logo.dart';
import '../../settings/presentation/language_controller.dart';
import '../application/clinova_pwa_bridge.dart';

/// Persisted when user taps "Дараа" on the auto-shown install sheet.
const kClinovaPwaInstallDismissedKey = 'clinova_pwa_install_prompt_dismissed_v1';

enum PwaInstructionProfile {
  androidChrome,
  iosSafari,
  iosOtherBrowser,
  desktopChrome,
}

PwaInstructionProfile resolvePwaProfile(String userAgent) {
  final u = userAgent.toLowerCase();
  final isIOSDevice =
      u.contains('iphone') ||
      u.contains('ipod') ||
      (u.contains('ipad')) ||
      (u.contains('macintosh') && u.contains('mobile'));
  if (isIOSDevice) {
    final isAppleWebKit = u.contains('applewebkit');
    final isChromeIOS = u.contains('crios');
    final isFirefoxIOS = u.contains('fxios');
    final isSafari =
        isAppleWebKit &&
        !u.contains('crios') &&
        !u.contains('fxios') &&
        !u.contains('edgios');
    if (isChromeIOS || isFirefoxIOS || (!isSafari && u.contains('chrome'))) {
      return PwaInstructionProfile.iosOtherBrowser;
    }
    return PwaInstructionProfile.iosSafari;
  }
  if (u.contains('android') && u.contains('chrome')) {
    return PwaInstructionProfile.androidChrome;
  }
  if (u.contains('android')) {
    return PwaInstructionProfile.androidChrome;
  }
  return PwaInstructionProfile.desktopChrome;
}

String pwaProfileInstructionLine(PwaInstructionProfile p) {
  switch (p) {
    case PwaInstructionProfile.androidChrome:
      return 'Суулгах товч дээр дарж Clinova-г Home screen дээр нэмээрэй.';
    case PwaInstructionProfile.iosSafari:
      return 'Safari дээр доорх Share товчийг дарна → Add to Home Screen → Add.';
    case PwaInstructionProfile.iosOtherBrowser:
      return 'iPhone дээр app шиг нэмэхийн тулд Safari browser-оор нээгээд Share → Add to Home Screen дарна уу.';
    case PwaInstructionProfile.desktopChrome:
      return 'Chrome address bar-ийн баруун талын Install icon дээр дарж суулгана.';
  }
}

/// Shows the install guide (bottom sheet on mobile, dialog on wide screens).
Future<void> showClinovaPwaInstallSheet(
  BuildContext context, {
  required WidgetRef ref,
  bool markDismissedOnLater = false,
}) async {
  if (!kIsWeb) return;
  if (clinovaPwaIsStandalone()) return;

  final profile = resolvePwaProfile(clinovaPwaUserAgent());
  final primaryBlue = const Color(0xFF2563EB);
  final navy = const Color(0xFF071B4D);

  Future<void> onInstall() async {
    await clinovaPwaPromptInstall();
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> onLater() async {
    if (markDismissedOnLater) {
      await ref
          .read(sharedPreferencesProvider)
          .setBool(kClinovaPwaInstallDismissedKey, true);
    }
    if (context.mounted) Navigator.of(context).pop();
  }

  final content = _InstallSheetContent(
    profile: profile,
    primaryBlue: primaryBlue,
    navy: navy,
    onInstall: onInstall,
    onLater: onLater,
  );

  final isNarrow = MediaQuery.sizeOf(context).width < 600;

  if (isNarrow) {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(ctx).bottom + 8,
          left: 16,
          right: 16,
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          clipBehavior: Clip.antiAlias,
          child: content,
        ),
      ),
    );
  } else {
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: content,
          ),
        ),
      ),
    );
  }
}

class _InstallSheetContent extends StatelessWidget {
  const _InstallSheetContent({
    required this.profile,
    required this.primaryBlue,
    required this.navy,
    required this.onInstall,
    required this.onLater,
  });

  final PwaInstructionProfile profile;
  final Color primaryBlue;
  final Color navy;
  final Future<void> Function() onInstall;
  final Future<void> Function() onLater;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.phone_android_rounded, color: primaryBlue, size: 28),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: ClinovaLogo(
                  size: 36,
                  variant: LogoVariant.dark,
                  showText: true,
                  responsive: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Clinova-г апп шиг ашиглах',
            style: theme.textTheme.titleLarge?.copyWith(
              color: navy,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Home screen дээр нэмээд хурдан нэвтэрч, цаг захиалга хийх боломжтой.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF475569),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF6FAFF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFD9E8FF)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: primaryBlue, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    pwaProfileInstructionLine(profile),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: navy,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: () => onInstall(),
            style: FilledButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text('Суулгах'),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => onLater(),
            child: const Text('Дараа'),
          ),
        ],
      ),
    );
  }
}

/// Auto-prompt once per device (until dismissed). Mount on welcome + auth flows.
class PwaWebAutoInstallTrigger extends ConsumerStatefulWidget {
  const PwaWebAutoInstallTrigger({super.key});

  @override
  ConsumerState<PwaWebAutoInstallTrigger> createState() =>
      _PwaWebAutoInstallTriggerState();
}

class _PwaWebAutoInstallTriggerState extends ConsumerState<PwaWebAutoInstallTrigger> {
  static bool _sessionShown = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _schedule());
  }

  Future<void> _schedule() async {
    if (!mounted) return;
    if (clinovaPwaIsStandalone()) return;
    final prefs = ref.read(sharedPreferencesProvider);
    if (prefs.getBool(kClinovaPwaInstallDismissedKey) ?? false) return;

    void tryOpen() {
      if (!mounted || _sessionShown) return;
      if (clinovaPwaIsStandalone()) return;
      _sessionShown = true;
      showClinovaPwaInstallSheet(
        context,
        ref: ref,
        markDismissedOnLater: true,
      );
    }

    clinovaPwaOnInstallAvailable(tryOpen);

    await Future<void>.delayed(const Duration(milliseconds: 2200));
    if (!mounted || _sessionShown) return;
    if (prefs.getBool(kClinovaPwaInstallDismissedKey) ?? false) return;
    tryOpen();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Settings: full-width card to reopen the install guide (always on web if not standalone).
class PwaSettingsInstallCard extends ConsumerWidget {
  const PwaSettingsInstallCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!kIsWeb || clinovaPwaIsStandalone()) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Вэб апп',
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        _SettingsStyleCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.add_to_home_screen_rounded,
              color: theme.colorScheme.primary,
            ),
            title: const Text('Clinova-г Home screen дээр нэмэх'),
            subtitle: const Text('Гар утас, таблет, компьютерт апп шиг ашиглах заавар'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => showClinovaPwaInstallSheet(
              context,
              ref: ref,
              markDismissedOnLater: false,
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _SettingsStyleCard extends StatelessWidget {
  const _SettingsStyleCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
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
