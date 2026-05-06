import 'package:diplom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/context_l10n.dart';
import '../../../core/navigation/go_router_pop.dart';
import '../../../core/widgets/clinova_logo.dart';
import '../../settings/presentation/language_controller.dart';
import '../application/auth_controller.dart';
import 'auth_marketing_side.dart';
import 'auth_scaffold.dart';
import 'auth_ui.dart';
import 'auth_view_entrance.dart';
import 'clinova_google_sign_in_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const _primaryBlue = Color(0xFF1769FF);
  static const _navy = Color(0xFF071B4D);
  static const _muted = Color(0xFF64748B);

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool obscurePassword = true;
  bool rememberMe = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(authControllerProvider.notifier).prepareFreshCredentialFlow();
      final prefs = ref.read(sharedPreferencesProvider);
      final saved = prefs.getString('clinova_saved_email');
      final remember = prefs.getBool('clinova_remember_me') ?? false;
      if (saved != null && saved.isNotEmpty && remember && mounted) {
        setState(() {
          emailController.text = saved;
          rememberMe = true;
        });
      }
    });
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  String? _validateLoginIdentifier(String v, AppLocalizations l10n) {
    final t = v.trim();
    if (t.isEmpty) return l10n.valEmailRequired;
    if (t.contains('@')) {
      if (!t.contains('.')) return l10n.valEmailInvalid;
      return null;
    }
    if (t.length < 2) return l10n.valEmailInvalid;
    return null;
  }

  Future<void> _persistRememberMe(String email) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (rememberMe) {
      await prefs.setString('clinova_saved_email', email.trim().toLowerCase());
      await prefs.setBool('clinova_remember_me', true);
    } else {
      await prefs.remove('clinova_saved_email');
      await prefs.setBool('clinova_remember_me', false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final authState = ref.watch(authControllerProvider);
    final auth = ref.read(authControllerProvider.notifier);
    final theme = Theme.of(context);

    ref.listen<AuthState>(authControllerProvider, (prev, next) {
      final needVerifyFromLogin =
          next.stage == AuthStage.codeSent &&
          next.otpIntent == OtpIntent.emailVerification &&
          (prev?.stage != AuthStage.codeSent ||
              prev?.otpIntent != OtpIntent.emailVerification);
      if (!needVerifyFromLogin || !context.mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/auth/verify');
      });
    });

    return AuthScaffold(
      leading: IconButton.filledTonal(
        onPressed: () => popOrGo(context, '/welcome'),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      sidePanel: const AuthMarketingSide(variant: AuthMarketingVariant.login),
      body: AuthViewEntrance(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthFormCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: ClinovaLogo(
                      size: 48,
                      variant: LogoVariant.dark,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    l10n.authWelcomeBack,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: _navy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.authWelcomeBackSubtitle,
                    style: theme.textTheme.bodyLarge?.copyWith(color: _muted),
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [
                      AutofillHints.email,
                      AutofillHints.username,
                    ],
                    decoration: InputDecoration(
                      labelText: l10n.authEmailLabel,
                      hintText: l10n.authEmailHint,
                      prefixIcon: const Icon(
                        Icons.person_outline_rounded,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: l10n.authPasswordLabel,
                      hintText: 'Enter your password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        tooltip: obscurePassword
                            ? l10n.authPasswordShow
                            : l10n.authPasswordHide,
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
                  Row(
                    children: [
                      Checkbox(
                        value: rememberMe,
                        activeColor: _primaryBlue,
                        onChanged: (v) =>
                            setState(() => rememberMe = v ?? false),
                      ),
                      Expanded(
                        child: Text(
                          l10n.authRememberMe,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push('/auth/forgot'),
                        child: Text(l10n.authForgotPasswordLink),
                      ),
                    ],
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
                      style: FilledButton.styleFrom(
                        backgroundColor: _primaryBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: authState.isBusy
                          ? null
                          : () async {
                              final err = _validateLoginIdentifier(
                                emailController.text,
                                l10n,
                              );
                              if (err != null) {
                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(
                                  SnackBar(content: Text(err)),
                                );
                                return;
                              }
                              if (passwordController.text.length < 8) {
                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(
                                  SnackBar(
                                    content: Text(l10n.valPasswordShort),
                                  ),
                                );
                                return;
                              }
                              auth.dismissError();
                              await _persistRememberMe(
                                emailController.text,
                              );
                              await auth.passwordLogin(
                                email: emailController.text.trim(),
                                password: passwordController.text,
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
                          : Text(l10n.authFormLogInTitle),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ClinovaGoogleSignInButton(isBusy: authState.isBusy),
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
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(l10n.authNewTo, style: theme.textTheme.bodyMedium),
                TextButton(
                  onPressed: () => context.push('/auth/register'),
                  child: Text(l10n.profileCreateAccount),
                ),
              ],
            ),
            const SizedBox(height: 6),
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
