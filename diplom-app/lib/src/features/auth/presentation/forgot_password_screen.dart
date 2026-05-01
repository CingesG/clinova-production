import 'package:diplom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/context_l10n.dart';
import '../../../core/navigation/go_router_pop.dart';
import '../../../core/widgets/clinova_logo.dart';
import '../application/auth_controller.dart';
import 'auth_scaffold.dart';
import 'auth_ui.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final emailController = TextEditingController();
  bool successShown = false;

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final authState = ref.watch(authControllerProvider);
    final auth = ref.read(authControllerProvider.notifier);
    final theme = Theme.of(context);

    ref.listen<AuthState>(authControllerProvider, (prev, next) {
      if (!successShown &&
          prev?.stage != AuthStage.codeSent &&
          next.stage == AuthStage.codeSent &&
          next.otpIntent == OtpIntent.forgotPassword) {
        successShown = true;
        if (context.mounted) {
          final loc = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                next.debugCode != null
                    ? '${loc.authCodeSentInbox} (${loc.authDevCode(next.debugCode!)})'
                    : loc.authForgotSnackGeneric,
              ),
            ),
          );
          context.push('/auth/reset-password');
        }
      }
    });

    return AuthScaffold(
      leading: IconButton.filledTonal(
        onPressed: () => popOrGo(context, '/auth/login'),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ClinovaLogo(
            size: 58,
            variant: LogoVariant.glass,
          ),
          const SizedBox(height: 20),
          Text(l10n.authResetAccessTitle, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            l10n.authResetAccessSubtitle,
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          AuthFormCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.authFormForgotTitle, style: theme.textTheme.titleLarge),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: l10n.authEmailLabel,
                    hintText: l10n.authEmailHint,
                    prefixIcon: const Icon(Icons.mail_outline_rounded),
                  ),
                ),
                if (authState.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  AuthErrorBanner(message: authState.errorMessage!),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: authState.isBusy
                        ? null
                        : () async {
                            final em = emailController.text.trim();
                            if (!em.contains('@')) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(l10n.valEmailInvalidShort)),
                              );
                              return;
                            }
                            auth.dismissError();
                            successShown = false;
                            await auth.requestForgotPassword(email: em);
                          },
                    child: authState.isBusy
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(l10n.authSendVerificationCode),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => context.go('/auth/login'),
                    child: Text(l10n.authBackToLogin),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
