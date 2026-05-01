import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/config/app_config.dart';
import '../../../core/localization/context_l10n.dart';
import '../application/auth_controller.dart';

/// Shared Google sign-in for login / register — backend creates & signs in the user (no app OTP).
Future<void> performClinovaGoogleSignIn(WidgetRef ref, BuildContext context) async {
  final auth = ref.read(authControllerProvider.notifier);
  final l10n = context.l10n;
  debugPrint('[Google] Button clicked');
  auth.dismissError();
  final googleClientId = AppConfig.googleClientId.trim();
  final google = GoogleSignIn(
    scopes: const ['email', 'openid'],
    clientId: googleClientId.isEmpty ? null : googleClientId,
    // google_sign_in_web does not support serverClientId.
    serverClientId: kIsWeb || googleClientId.isEmpty ? null : googleClientId,
  );
  try {
    await google.signOut();
  } catch (_) {}

  GoogleSignInAccount? account;
  try {
    debugPrint('[Google] Google sign-in started');
    account = await google.signIn();
  } catch (e) {
    debugPrint('[Google] signIn() failed: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google sign-in failed: $e')),
      );
    }
    return;
  }

  if (account == null) {
    debugPrint('[Google] User cancelled account picker');
    return;
  }

  final ga = await account.authentication;
  final idToken = ga.idToken;
  if (idToken == null || idToken.isEmpty) {
    final msg = kIsWeb
        ? 'Google вэб: Cloud Console-д Web OAuth client үүсгээд Authorized JS origins-д Vercel URL нэмээд dart-define GOOGLE_CLIENT_ID / backend GOOGLE_CLIENT_ID ижил эсэхийг шалгана.'
        : 'Google id tokens ирээгүй байна. Backend дээрх GOOGLE_CLIENT_ID нь платформыг давхардсан OAuth client ID эсэхийг шалга (голчлон Web Application client id). ${l10n.authGoogleContinue}';
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
    return;
  }

  await auth.googleSignIn(idToken: idToken);
  if (!context.mounted) return;
  final err = ref.read(authControllerProvider).errorMessage;
  if (err != null) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
  }
}
