import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/clinova_circle_avatar.dart';

class ClinovaToast {
  ClinovaToast({
    required this.id,
    required this.title,
    required this.body,
    this.avatarUrl,
    this.initials = '?',
  });

  final String id;
  final String title;
  final String body;
  final String? avatarUrl;
  final String initials;
}

final clinovaRealtimeToastsProvider =
    NotifierProvider<ClinovaRealtimeToastsNotifier, List<ClinovaToast>>(
  ClinovaRealtimeToastsNotifier.new,
);

class ClinovaRealtimeToastsNotifier extends Notifier<List<ClinovaToast>> {
  DateTime? _lastPushAt;

  @override
  List<ClinovaToast> build() => [];

  void push(ClinovaToast toast) {
    final now = DateTime.now();
    if (_lastPushAt != null &&
        now.difference(_lastPushAt!) < const Duration(milliseconds: 1800)) {
      return;
    }
    _lastPushAt = now;
    state = [...state, toast];
    Future<void>.delayed(const Duration(seconds: 9), () {
      dismiss(toast.id);
    });
  }

  void dismiss(String id) {
    state = state.where((t) => t.id != id).toList();
  }
}

/// Top-aligned lightweight message stack (desktop top-right, mobile top).
class ClinovaRealtimeToastLayer extends ConsumerWidget {
  const ClinovaRealtimeToastLayer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toasts = ref.watch(clinovaRealtimeToastsProvider);
    final mq = MediaQuery.of(context);
    final isWide = mq.size.width >= 720;

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: mq.padding.top + 12,
          right: isWide ? 16 : 12,
          left: isWide ? null : 12,
          child: IgnorePointer(
            ignoring: toasts.isEmpty,
            child: Column(
              crossAxisAlignment:
                  isWide ? CrossAxisAlignment.end : CrossAxisAlignment.stretch,
              children: [
                for (final t in toasts)
                  _ClinovaToastCard(
                    toast: t,
                    onDismiss: () => ref
                        .read(clinovaRealtimeToastsProvider.notifier)
                        .dismiss(t.id),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ClinovaToastCard extends StatelessWidget {
  const _ClinovaToastCard({
    required this.toast,
    required this.onDismiss,
  });

  final ClinovaToast toast;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        elevation: 6,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.97),
        child: InkWell(
          onTap: onDismiss,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClinovaCircleAvatar(
                    radius: 22,
                    initialsText: toast.initials,
                    backgroundColor: const Color(0xFFE8F0FE),
                    foregroundColor: const Color(0xFF1D4ED8),
                    networkUrl: toast.avatarUrl,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          toast.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          toast.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF475569),
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Soft haptic only (avoid loud sounds). Optional asset hook-up later.
Future<void> clinovaPlaySoftRealtimeCue() async {
  if (kIsWeb) return;
  try {
    await HapticFeedback.selectionClick();
  } catch (_) {}
}
