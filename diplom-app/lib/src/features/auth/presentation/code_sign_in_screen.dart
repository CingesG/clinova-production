import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/context_l10n.dart';
import '../../../core/navigation/go_router_pop.dart';
import '../../../core/widgets/clinova_logo.dart';
import '../application/auth_controller.dart';
import 'auth_scaffold.dart';
import 'auth_ui.dart';

class CodeSignInScreen extends ConsumerStatefulWidget {
  const CodeSignInScreen({super.key});

  @override
  ConsumerState<CodeSignInScreen> createState() => _CodeSignInScreenState();
}

class _CodeSignInScreenState extends ConsumerState<CodeSignInScreen> {
  final emailController = TextEditingController();
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();

  @override
  void dispose() {
    emailController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final authState = ref.watch(authControllerProvider);
    final auth = ref.read(authControllerProvider.notifier);
    final theme = Theme.of(context);

    ref.listen<AuthState>(authControllerProvider, (prev, next) {
      if (prev?.stage != AuthStage.codeSent &&
          next.stage == AuthStage.codeSent &&
          next.otpIntent == OtpIntent.signInCode) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.authCodeSentInbox),
            ),
          );
          context.push('/auth/verify');
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
          Text(l10n.authCodeSignInTitle, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            l10n.authCodeSignInSubtitle,
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          AuthFormCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.authRequestCodeTitle, style: theme.textTheme.titleLarge),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: l10n.authEmailLabel,
                    prefixIcon: const Icon(Icons.mail_outline_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: firstNameController,
                  decoration: InputDecoration(
                    labelText: l10n.authFirstName,
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lastNameController,
                  decoration: InputDecoration(
                    labelText: l10n.authLastName,
                    prefixIcon: const Icon(Icons.badge_outlined),
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
                            await auth.requestOtp(
                              email: em,
                              firstName: firstNameController.text.trim(),
                              lastName: lastNameController.text.trim(),
                            );
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
                        : Text(l10n.authSendCodeButton),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => context.go('/auth/login'),
                    child: Text(l10n.authUsePassword),
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
