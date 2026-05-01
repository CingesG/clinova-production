import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../localization/context_l10n.dart';

/// Shown when a guest attempts a protected action (e.g. confirm booking).
Future<void> showGuestAuthPrompt(BuildContext context) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  final l10n = context.l10n;

  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (ctx) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.lock_person_rounded,
                size: 44,
                color: cs.primary,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.guestAuthTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.guestAuthBody,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF475467),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  ctx.push('/auth/login');
                },
                child: Text(l10n.profileSignIn),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  ctx.push('/auth/register');
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF047857),
                  side: const BorderSide(color: Color(0xFFA7F3D0)),
                  backgroundColor: const Color(0xFFECFDF5),
                ),
                child: Text(l10n.profileCreateAccount),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(l10n.guestAuthNotNow),
              ),
            ],
          ),
        ),
      );
    },
  );
}
