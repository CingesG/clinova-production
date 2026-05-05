import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'pwa_install.dart';

/// Web-only install prompt: shows when Chromium exposes [beforeinstallprompt]
/// (we call `preventDefault` in index.html, so the browser mini-infobar is
/// suppressed — this bar is the replacement).
class ClinovaWebInstallBar extends StatefulWidget {
  const ClinovaWebInstallBar({super.key});

  @override
  State<ClinovaWebInstallBar> createState() => _ClinovaWebInstallBarState();
}

class _ClinovaWebInstallBarState extends State<ClinovaWebInstallBar> {
  StreamSubscription<void>? _sub;
  StreamSubscription<void>? _installedSub;
  bool _installPromptReady = false;
  bool _sessionDismissed = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) return;
    if (pwaIsWebStandalone()) {
      _sessionDismissed = true;
      return;
    }
    _installedSub = pwaAppInstalledStream().listen((_) {
      if (!mounted) return;
      setState(() => _sessionDismissed = true);
    });
    _sub = pwaInstallPromptAvailableStream().listen((_) {
      if (!mounted) return;
      if (pwaIsWebStandalone()) {
        setState(() => _sessionDismissed = true);
        return;
      }
      if (_deferredReady()) {
        setState(() => _installPromptReady = true);
      }
    });
    if (_deferredReady()) {
      _installPromptReady = true;
    }
  }

  bool _deferredReady() => pwaIsDeferredInstallPromptAvailable();

  @override
  void dispose() {
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
      setState(() => _sessionDismissed = true);
    } else {
      setState(() => _installPromptReady = _deferredReady());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || _sessionDismissed || pwaIsWebStandalone()) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    final border = Border(
      top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.9)),
    );

    if (!_installPromptReady) {
      return const SizedBox.shrink();
    }

    return Material(
      elevation: 6,
      shadowColor: Colors.black38,
      color: scheme.surfaceContainerHigh.withValues(alpha: 0.97),
      child: Container(
        decoration: BoxDecoration(border: border),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.install_mobile_rounded,
                        color: scheme.primary, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Энэхүү төхөөрөмж дээр Clinova-г апп шиг ашиглах бол доорх товчийг дарна уу.',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(height: 1.35),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 4,
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
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Хаах',
                        onPressed: () =>
                            setState(() => _sessionDismissed = true),
                        icon: const Icon(Icons.close_rounded, size: 20),
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
}
