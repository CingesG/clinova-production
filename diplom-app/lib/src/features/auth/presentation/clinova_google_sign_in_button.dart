import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'clinova_google_sign_in_button_mobile.dart'
    if (dart.library.html) 'clinova_google_sign_in_button_web.dart';

/// Platform Google entry: **web** uses GIS [renderButton]; **mobile** uses [GoogleSignIn.signIn].
class ClinovaGoogleSignInButton extends ConsumerWidget {
  const ClinovaGoogleSignInButton({super.key, required this.isBusy});

  final bool isBusy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return clinovaGoogleSignInButtonImpl(context, ref, isBusy);
  }
}
