import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/config/app_config.dart';
import '../application/auth_controller.dart';

const String _kMnGoogleCancelled = 'Google нэвтрэлт цуцлагдлаа.';
const String _kMnClientIdMissing = 'Google Client ID тохируулагдаагүй байна.';
const String _kMnConfigIncompleteDeploy =
    'Google нэвтрэлт тохиргоо дутуу байна. Дахин deploy хийж шалгана уу.';
const String _kMnSignInFailed = 'Google нэвтрэлт амжилтгүй боллоо.';
const String _kMnConfigIncompleteShort = 'Google тохиргоо дутуу байна.';

void _showGoogleSnack(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

String _mapGoogleSignInException(Object e) {
  final s = e.toString();
  if (s.contains('Null check operator used on a null value')) {
    return _kMnConfigIncompleteDeploy;
  }
  if (s.contains('popup_closed') ||
      s.contains('popup closed') ||
      s.contains('access_denied') ||
      s.contains('user_canceled')) {
    return _kMnGoogleCancelled;
  }
  return _kMnSignInFailed;
}

/// Shared Google sign-in for login / register — backend creates & signs in the user (no app OTP).
Future<void> performClinovaGoogleSignIn(WidgetRef ref, BuildContext context) async {
  final auth = ref.read(authControllerProvider.notifier);
  debugPrint('[Google] Button clicked');
  auth.dismissError();

  final googleClientId = AppConfig.googleClientId.trim();
  if (googleClientId.isEmpty) {
    _showGoogleSnack(context, _kMnClientIdMissing);
    return;
  }

  // Web: OAuth web client in constructor + index.html meta. Mobile: platform OAuth client from
  // native config; serverClientId must be the *web* client ID so id_token aud matches backend.
  // Basic Sign in with Google only — no Gmail/Drive/Calendar or other sensitive scopes.
  final google = GoogleSignIn(
    scopes: const ['openid', 'email', 'profile'],
    clientId: kIsWeb ? googleClientId : null,
    serverClientId: kIsWeb ? null : googleClientId,
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
    _showGoogleSnack(context, _mapGoogleSignInException(e));
    return;
  }

  if (account == null) {
    debugPrint('[Google] User cancelled account picker');
    if (!context.mounted) return;
    _showGoogleSnack(context, _kMnGoogleCancelled);
    return;
  }

  GoogleSignInAuthentication ga;
  try {
    ga = await account.authentication;
  } catch (e) {
    debugPrint('[Google] authentication failed: $e');
    if (!context.mounted) return;
    _showGoogleSnack(context, _mapGoogleSignInException(e));
    return;
  }

  final idToken = ga.idToken;
  if (idToken == null || idToken.isEmpty) {
    if (!context.mounted) return;
    _showGoogleSnack(
      context,
      kIsWeb ? _kMnConfigIncompleteDeploy : _kMnConfigIncompleteShort,
    );
    return;
  }

  await auth.googleSignIn(idToken: idToken);
  if (!context.mounted) return;
  final err = ref.read(authControllerProvider).errorMessage;
  if (err != null) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
  }
}
