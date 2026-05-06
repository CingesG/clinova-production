import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/pwa/presentation/install_app_banner.dart'
    show kClinovaPwaInstallDismissedKey;
import '../../features/settings/presentation/language_controller.dart';
import '../widgets/premium_healthcare_shell.dart';
import 'pwa_install.dart';

/// Web-only install prompt: Chromium [beforeinstallprompt] (suppressed in index.html).
///
/// Rendered as a small bottom [Positioned] strip in [ClinovaApp] — never as a full-screen
/// layer — so the rest of the page stays clickable (see app.dart).
class ClinovaWebInstallBar extends ConsumerStatefulWidget {
  const ClinovaWebInstallBar({super.key});

  @override
  ConsumerState<ClinovaWebInstallBar> createState() =>
      _ClinovaWebInstallBarState();
}

class _ClinovaWebInstallBarState extends ConsumerState<ClinovaWebInstallBar> {
  StreamSubscription<void>? _sub;
  StreamSubscription<void>? _installedSub;
  Timer? _autoDismissTimer;
  bool _installPromptReady = false;
  bool _sessionDismissed = false;
  bool _streamsAttached = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) return;
    if (pwaIsWebStandalone()) {
      _sessionDismissed = true;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_bootstrap()));
  }

  Future<void> _bootstrap() async {
    if (!mounted || !kIsWeb) return;
    if (pwaIsWebStandalone()) {
      if (mounted) setState(() => _sessionDismissed = true);
      return;
    }
    final prefs = ref.read(sharedPreferencesProvider);
    if (prefs.getBool(kClinovaPwaInstallDismissedKey) ?? false) {
      if (mounted) setState(() => _sessionDismissed = true);
      return;
    }
    _attachStreams();
    if (_deferredReady()) {
      if (mounted) {
        setState(() => _installPromptReady = true);
        _startAutoDismissTimer();
      }
    }
  }

  void _attachStreams() {
    if (_streamsAttached) return;
    _streamsAttached = true;
    _installedSub = pwaAppInstalledStream().listen((_) {
      unawaited(_rememberDismissal());
    });
    _sub = pwaInstallPromptAvailableStream().listen((_) {
      if (!mounted) return;
      if (pwaIsWebStandalone()) {
        unawaited(_rememberDismissal());
        return;
      }
      if (_deferredReady()) {
        setState(() => _installPromptReady = true);
        _startAutoDismissTimer();
      }
    });
  }

  bool _deferredReady() => pwaIsDeferredInstallPromptAvailable();

  void _startAutoDismissTimer() {
    if (!mounted || _sessionDismissed || !_installPromptReady) return;
    _autoDismissTimer?.cancel();
    _autoDismissTimer = Timer(const Duration(seconds: 30), () {
      if (!mounted) return;
      unawaited(_rememberDismissal());
    });
  }

  Future<void> _rememberDismissal() async {
    _autoDismissTimer?.cancel();
    _autoDismissTimer = null;
    try {
      await ref
          .read(sharedPreferencesProvider)
          .setBool(kClinovaPwaInstallDismissedKey, true);
    } catch (_) {}
    if (mounted) setState(() => _sessionDismissed = true);
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _sub?.cancel();
    _installedSub?.cancel();
    super.dispose();
  }

  Future<void> _showManualInstallHelp(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clinova суулгах'),
        content: SingleChildScrollView(
          child: Text(
            pwaFallbackInstallHint(),
            style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Ойлголоо'),
          ),
        ],
      ),
    );
  }

  Future<void> _onInstallTap() async {
    final ok = await pwaPromptInstall();
    if (!mounted) return;
    if (ok || pwaIsWebStandalone()) {
      await _rememberDismissal();
    } else {
      setState(() => _installPromptReady = _deferredReady());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || _sessionDismissed || pwaIsWebStandalone()) {
      return const SizedBox.shrink();
    }

    if (!_installPromptReady) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 6,
      shadowColor: Colors.black38,
      color: scheme.surfaceContainerHigh.withValues(alpha: 0.98),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ClinovaPremium.radiusMd),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.9)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        minimum: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.install_mobile_rounded,
                      color: scheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        'Энэхүү төхөөрөмж дээр Clinova-г апп шиг ашиглах бол доорх товчийг дарна уу.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              height: 1.35,
                            ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Хаах',
                    onPressed: () => unawaited(_rememberDismissal()),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.all(8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: Icon(Icons.close_rounded, size: 22, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => _showManualInstallHelp(context),
                    child: const Text('Заавар'),
                  ),
                  FilledButton.tonal(
                    onPressed: _onInstallTap,
                    child: const Text('Install Clinova'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
