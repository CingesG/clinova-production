import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_web/web_only.dart';

import '../../../core/localization/context_l10n.dart';
import '../../../core/config/app_config.dart';
import '../application/auth_controller.dart';
import 'clinova_google_sign_in_common.dart';

GoogleSignIn? _clinovaWebGoogleSignIn;

GoogleSignIn _webGoogleSignIn() {
  final id = AppConfig.googleClientId.trim();
  _clinovaWebGoogleSignIn ??= GoogleSignIn(
    scopes: const ['openid', 'email', 'profile'],
    clientId: id,
  );
  return _clinovaWebGoogleSignIn!;
}

/// Web: Google Identity Services button ([renderButton]) — no deprecated popup [signIn].
Widget clinovaGoogleSignInButtonImpl(
  BuildContext context,
  WidgetRef ref,
  bool isBusy,
) {
  final clientId = AppConfig.googleClientId.trim();
  if (clientId.isEmpty) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF1D4ED8),
          side: const BorderSide(color: Color(0xFFBFDBFE)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        onPressed: isBusy
            ? null
            : () => showClinovaGoogleSnack(context, kMnClientIdMissing),
        child: Text(context.l10n.authGoogleContinue),
      ),
    );
  }

  return SizedBox(
    width: double.infinity,
    height: 52,
    child: IgnorePointer(
      ignoring: isBusy,
      child: Opacity(
        opacity: isBusy ? 0.55 : 1,
        child: _ClinovaWebGsiButton(ref: ref),
      ),
    ),
  );
}

class _ClinovaWebGsiButton extends StatefulWidget {
  const _ClinovaWebGsiButton({required this.ref});

  final WidgetRef ref;

  @override
  State<_ClinovaWebGsiButton> createState() => _ClinovaWebGsiButtonState();
}

class _ClinovaWebGsiButtonState extends State<_ClinovaWebGsiButton> {
  StreamSubscription<GoogleSignInAccount?>? _sub;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    final google = _webGoogleSignIn();
    _sub = google.onCurrentUserChanged.listen(_onUserChanged);
    unawaited(_primeWebSession(google));
  }

  Future<void> _primeWebSession(GoogleSignIn google) async {
    try {
      await google.signOut();
    } catch (_) {}
  }

  Future<void> _onUserChanged(GoogleSignInAccount? account) async {
    if (account == null || !mounted || _processing) return;
    _processing = true;
    widget.ref.read(authControllerProvider.notifier).dismissError();

    try {
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        if (mounted) {
          showClinovaGoogleSnack(context, kMnConfigIncompleteShort);
        }
        return;
      }

      await widget.ref
          .read(authControllerProvider.notifier)
          .googleSignIn(idToken: idToken);

      if (!mounted) return;
      final err = widget.ref.read(authControllerProvider).errorMessage;
      if (err != null) {
        showClinovaGoogleSnack(context, err);
      }
    } catch (e, st) {
      debugPrint('[Google/Web] credential flow failed: $e\n$st');
      if (mounted) {
        showClinovaGoogleSnack(context, kMnSignInFailed);
      }
    } finally {
      try {
        await _webGoogleSignIn().signOut();
      } catch (_) {}
      _processing = false;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: renderButton(
        configuration: GSIButtonConfiguration(
          type: GSIButtonType.standard,
          theme: GSIButtonTheme.outline,
          size: GSIButtonSize.large,
          text: GSIButtonText.continueWith,
          shape: GSIButtonShape.pill,
          minimumWidth: 400,
        ),
      ),
    );
  }
}
