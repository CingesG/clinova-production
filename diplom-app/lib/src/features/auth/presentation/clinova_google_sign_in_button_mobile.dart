import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/context_l10n.dart';
import 'perform_clinova_google_sign_in.dart';

/// Android / iOS: classic [GoogleSignIn.signIn] flow (unchanged).
Widget clinovaGoogleSignInButtonImpl(
  BuildContext context,
  WidgetRef ref,
  bool isBusy,
) {
  final l10n = context.l10n;
  return SizedBox(
    width: double.infinity,
    height: 52,
    child: OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF1D4ED8),
        side: const BorderSide(color: Color(0xFFBFDBFE)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      onPressed: isBusy ? null : () => performClinovaGoogleSignIn(ref, context),
      icon: const Text(
        'G',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Color(0xFF4285F4),
        ),
      ),
      label: Text(l10n.authGoogleContinue),
    ),
  );
}
