import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/config/app_config.dart';
import '../application/auth_controller.dart';
import 'clinova_google_sign_in_common.dart';

String _mapGoogleSignInException(Object e) {
  final s = e.toString();
  if (s.contains('Null check operator used on a null value')) {
    return 'Google нэвтрэлт тохиргоо дутуу байна. Дахин deploy хийж шалгана уу.';
  }
  if (s.contains('popup_closed') ||
      s.contains('popup closed') ||
      s.contains('access_denied') ||
      s.contains('user_canceled')) {
    return kMnGoogleCancelled;
  }
  return kMnSignInFailed;
}

/// Android / iOS Google sign-in — [GoogleSignIn.signIn]. Web uses [ClinovaGoogleSignInButton].
Future<void> performClinovaGoogleSignIn(WidgetRef ref, BuildContext context) async {
  final auth = ref.read(authControllerProvider.notifier);
  debugPrint('[Google] Button clicked (mobile)');
  auth.dismissError();

  final googleClientId = AppConfig.googleClientId.trim();
  if (googleClientId.isEmpty) {
    showClinovaGoogleSnack(context, kMnClientIdMissing);
    return;
  }

  final google = GoogleSignIn(
    scopes: const ['openid', 'email', 'profile'],
    serverClientId: googleClientId,
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
    if (!context.mounted) return;
    showClinovaGoogleSnack(context, _mapGoogleSignInException(e));
    return;
  }

  if (account == null) {
    debugPrint('[Google] User cancelled account picker');
    if (!context.mounted) return;
    showClinovaGoogleSnack(context, kMnGoogleCancelled);
    return;
  }

  GoogleSignInAuthentication ga;
  try {
    ga = await account.authentication;
  } catch (e) {
    debugPrint('[Google] authentication failed: $e');
    if (!context.mounted) return;
    showClinovaGoogleSnack(context, _mapGoogleSignInException(e));
    return;
  }

  final idToken = ga.idToken;
  if (idToken == null || idToken.isEmpty) {
    if (!context.mounted) return;
    showClinovaGoogleSnack(context, kMnConfigIncompleteShort);
    return;
  }

  await auth.googleSignIn(idToken: idToken);
  if (!context.mounted) return;
  final err = ref.read(authControllerProvider).errorMessage;
  if (err != null) {
    showClinovaGoogleSnack(context, err);
  }
}
