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

class CodeSignInScreen extends ConsumerStatefulWidget {
  const CodeSignInScreen({super.key});

  @override
  ConsumerState<CodeSignInScreen> createState() => _CodeSignInScreenState();
}

class _CodeSignInScreenState extends ConsumerState<CodeSignInScreen> {
  static const _navy = Color(0xFF071B4D);
  static const _muted = Color(0xFF64748B);
  static const _primaryBlue = Color(0xFF1769FF);

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
            SnackBar(content: Text(context.l10n.authCodeSentInbox)),
          );
          context.push('/auth/verify');
        }
      }
    });

    return AuthScaffold(
      leading: Tooltip(
        message: l10n.authFormLogInTitle,
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
                    l10n.authCodeSignInTitle,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: _navy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.authCodeSignInSubtitle,
                    style: theme.textTheme.bodyLarge?.copyWith(color: _muted),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    l10n.authRequestCodeTitle,
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
                      prefixIcon: const Icon(Icons.mail_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: firstNameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: l10n.authFirstName,
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: lastNameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: l10n.authLastName,
                      prefixIcon: const Icon(Icons.badge_outlined),
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
                    height: 52,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: () => context.go('/auth/login'),
                      child: Text(l10n.authUsePassword),
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
