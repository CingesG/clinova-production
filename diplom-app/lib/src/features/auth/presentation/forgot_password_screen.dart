import 'package:diplom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/context_l10n.dart';
import '../../../core/navigation/go_router_pop.dart';
import '../../../core/widgets/clinova_logo.dart';
import '../application/auth_controller.dart';
import 'auth_marketing_side.dart';
import 'auth_scaffold.dart';
import 'auth_ui.dart';
import 'auth_view_entrance.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  static const _navy = Color(0xFF071B4D);
  static const _muted = Color(0xFF64748B);
  static const _primaryBlue = Color(0xFF1769FF);

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
      leading: Tooltip(
        message: l10n.authBackToLogin,
        child: IconButton.filledTonal(
          onPressed: () => popOrGo(context, '/auth/login'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      sidePanel: const AuthMarketingSide(
        variant: AuthMarketingVariant.recovery,
      ),
      body: AuthViewEntrance(
        delay: const Duration(milliseconds: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthFormCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: ClinovaLogo(size: 48, variant: LogoVariant.dark),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    l10n.authResetAccessTitle,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: _navy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.authResetAccessSubtitle,
                    style: theme.textTheme.bodyLarge?.copyWith(color: _muted),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    l10n.authFormForgotTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: _navy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
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
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _primaryBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: authState.isBusy
                          ? null
                          : () async {
                              final em = emailController.text.trim();
                              if (!em.contains('@')) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(l10n.valEmailInvalidShort),
                                  ),
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
                    height: 52,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: () => context.go('/auth/login'),
                      child: Text(l10n.authBackToLogin),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              l10n.authFooterSecure,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: _muted,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
