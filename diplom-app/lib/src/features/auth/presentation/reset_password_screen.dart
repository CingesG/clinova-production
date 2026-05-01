import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/context_l10n.dart';
import '../../../core/widgets/clinova_logo.dart';
import '../application/auth_controller.dart';
import 'auth_scaffold.dart';
import 'auth_ui.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
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
      leading: IconButton.filledTonal(
        onPressed: () => context.go('/auth/forgot'),
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
          Text(
            l10n.resetPasswordTitle,
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            email.isEmpty ? l10n.authVerifyEmailMissing : email,
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          AuthFormCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                const SizedBox(height: 12),
                TextField(
                  controller: passController,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: l10n.resetPasswordNewLabel,
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
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
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: authState.isBusy || email.isEmpty
                        ? null
                        : () async {
                            if (passController.text.length < 8) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(l10n.valPasswordShort)),
                              );
                              return;
                            }
                            if (passController.text !=
                                confirmController.text) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(l10n.valPasswordsNoMatch)),
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
                                    content: Text(l10n.resetPasswordSuccess)),
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
        ],
      ),
    );
  }
}
