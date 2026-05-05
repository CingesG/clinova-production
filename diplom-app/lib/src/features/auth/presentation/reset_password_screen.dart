import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/context_l10n.dart';
import '../../../core/widgets/clinova_logo.dart';
import '../application/auth_controller.dart';
import 'auth_marketing_side.dart';
import 'auth_scaffold.dart';
import 'auth_ui.dart';
import 'auth_view_entrance.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  static const _navy = Color(0xFF071B4D);
  static const _muted = Color(0xFF64748B);
  static const _primaryBlue = Color(0xFF1769FF);

  final otpController = TextEditingController();
  final passController = TextEditingController();
  final confirmController = TextEditingController();
  bool obscure = true;

  @override
  void dispose() {
    otpController.dispose();
    passController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final authState = ref.watch(authControllerProvider);
    final auth = ref.read(authControllerProvider.notifier);
    final theme = Theme.of(context);
    final email = authState.pendingEmail ?? '';

    return AuthScaffold(
      leading: Tooltip(
        message: l10n.authFormForgotTitle,
        child: IconButton.filledTonal(
          onPressed: () => context.go('/auth/forgot'),
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
                    l10n.resetPasswordTitle,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: _navy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    email.isEmpty ? l10n.authVerifyEmailMissing : email,
                    style: theme.textTheme.bodyLarge?.copyWith(color: _muted),
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: l10n.authOtpFieldLabel,
                      prefixIcon: const Icon(Icons.pin_outlined),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: passController,
                    obscureText: obscure,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: l10n.resetPasswordNewLabel,
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        tooltip: obscure
                            ? l10n.authPasswordShow
                            : l10n.authPasswordHide,
                        onPressed: () => setState(() => obscure = !obscure),
                        icon: Icon(
                          obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmController,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: l10n.resetPasswordConfirmLabel,
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
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
                      onPressed: authState.isBusy || email.isEmpty
                          ? null
                          : () async {
                              if (passController.text.length < 8) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(l10n.valPasswordShort),
                                  ),
                                );
                                return;
                              }
                              if (passController.text !=
                                  confirmController.text) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(l10n.valPasswordsNoMatch),
                                  ),
                                );
                                return;
                              }
                              auth.dismissError();
                              await auth.resetPasswordWithOtp(
                                otp: otpController.text.trim(),
                                newPassword: passController.text,
                              );
                              if (!context.mounted) return;
                              final st = ref.read(authControllerProvider);
                              if (st.errorMessage == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(l10n.resetPasswordSuccess),
                                  ),
                                );
                                context.go('/auth/login');
                              }
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
                          : Text(l10n.resetPasswordSubmit),
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
