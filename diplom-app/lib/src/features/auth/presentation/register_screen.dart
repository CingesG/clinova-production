import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatting/mongolia_phone.dart';
import '../../../core/localization/context_l10n.dart';
import '../../../core/navigation/go_router_pop.dart';
import '../../../core/widgets/clinova_logo.dart';
import '../application/auth_controller.dart';
import 'auth_scaffold.dart';
import 'auth_ui.dart';
import 'perform_clinova_google_sign_in.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  static const _navy = Color(0xFF071B4D);
  static const _muted = Color(0xFF64748B);

  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();
  bool obscurePassword = true;
  bool obscureConfirm = true;

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final authState = ref.watch(authControllerProvider);
    final auth = ref.read(authControllerProvider.notifier);
    final theme = Theme.of(context);

    ref.listen<AuthState>(authControllerProvider, (prev, next) {
      final enteredEmailOtpFlow =
          next.stage == AuthStage.codeSent &&
          next.otpIntent == OtpIntent.register &&
          (prev?.stage != AuthStage.codeSent ||
              prev?.otpIntent != OtpIntent.register);
      if (!enteredEmailOtpFlow || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.authRegisterCheckEmailSnack)),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/auth/verify');
      });
    });

    return AuthScaffold(
      leading: IconButton.filledTonal(
        onPressed: () => popOrGo(context, '/welcome'),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ClinovaLogo(size: 58, variant: LogoVariant.glass),
          const SizedBox(height: 20),
          Text(
            l10n.authCreateAccountTitle,
            style: theme.textTheme.headlineMedium?.copyWith(color: _navy),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.authCreateAccountSubtitle,
            style: theme.textTheme.bodyLarge?.copyWith(color: _muted),
          ),
          const SizedBox(height: 20),
          AuthFormCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: firstNameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: l10n.authFirstName,
                          prefixIcon: const Icon(
                            Icons.person_outline_rounded,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: lastNameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: l10n.authLastName,
                          prefixIcon: const Icon(Icons.badge_outlined),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: l10n.authEmailLabel,
                    hintText: l10n.authEmailHint,
                    prefixIcon: const Icon(Icons.mail_outline_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Утасны дугаар',
                    hintText: '88071574',
                    prefixIcon: Icon(Icons.phone_iphone_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: l10n.authPasswordLabel,
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      onPressed: () => setState(
                        () => obscurePassword = !obscurePassword,
                      ),
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmController,
                  obscureText: obscureConfirm,
                  decoration: InputDecoration(
                    labelText: l10n.authConfirmPasswordLabel,
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      onPressed: () => setState(
                        () => obscureConfirm = !obscureConfirm,
                      ),
                      icon: Icon(
                        obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
                if (authState.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  AuthErrorBanner(message: authState.errorMessage!),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: authState.isBusy
                        ? null
                        : () async {
                            final fn = firstNameController.text.trim();
                            final ln = lastNameController.text.trim();
                            final em = emailController.text.trim();
                            if (fn.isEmpty || ln.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(l10n.valFullName)),
                              );
                              return;
                            }
                            if (!em.contains('@')) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(l10n.valEmailInvalidShort),
                                ),
                              );
                              return;
                            }
                            final normalizedPhone = normalizeMnPhoneForApi(
                              phoneController.text,
                            );
                            if (normalizedPhone == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Утасны дугаар буруу байна.'),
                                ),
                              );
                              return;
                            }
                            final p = passwordController.text;
                            if (p.length < 8) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(l10n.valPasswordShort)),
                              );
                              return;
                            }
                            if (p != confirmController.text) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(l10n.valPasswordsNoMatch)),
                              );
                              return;
                            }
                            auth.dismissError();
                            await auth.registerWithPassword(
                              email: em,
                              password: p,
                              firstName: fn,
                              lastName: ln,
                              phoneNumber: normalizedPhone,
                            );
                            if (!context.mounted) return;
                            final nextState = ref.read(
                              authControllerProvider,
                            );
                            final error =
                                nextState.errorMessage?.toLowerCase() ?? '';
                            if (error.contains('already registered') ||
                                error.contains('already exists')) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Ta burtgelttei baina. Newtreh huudas ruu shiljlee.',
                                  ),
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
                        : Text(l10n.authFormRegisterTitle),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1D4ED8),
                      side: const BorderSide(color: Color(0xFFBFDBFE)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: authState.isBusy
                        ? null
                        : () => performClinovaGoogleSignIn(ref, context),
                    icon: const Text(
                      'G',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF4285F4),
                      ),
                    ),
                    label: Text(l10n.authGoogleContinue),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.authGoogleSkipsOtp,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _muted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                l10n.authAlreadyHaveAccount,
                style: theme.textTheme.bodyMedium,
              ),
              TextButton(
                onPressed: () => context.go('/auth/login'),
                child: Text(l10n.authFormLogInTitle),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
