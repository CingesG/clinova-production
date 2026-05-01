import 'dart:async';

import 'package:diplom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/context_l10n.dart';
import '../../../core/navigation/go_router_pop.dart';
import '../../../core/widgets/clinova_logo.dart';
import '../../settings/presentation/language_controller.dart';
import '../application/auth_controller.dart';
import 'auth_scaffold.dart';
import 'auth_ui.dart';
import 'perform_clinova_google_sign_in.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const _primaryBlue = Color(0xFF1769FF);
  static const _navy = Color(0xFF071B4D);
  static const _muted = Color(0xFF64748B);
  static const _teal = Color(0xFF0EA5A4);

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final _otpControllers = List.generate(6, (_) => TextEditingController());
  final _otpFocusNodes = List.generate(6, (_) => FocusNode());
  bool obscurePassword = true;
  bool rememberMe = false;
  Timer? _cooldownTimer;
  int _resendSeconds = 60;

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
    _cooldownTimer?.cancel();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String? _validateEmail(String v, AppLocalizations l10n) {
    final t = v.trim();
    if (t.isEmpty) return l10n.valEmailRequired;
    if (!t.contains('@')) return l10n.valEmailInvalid;
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

  void _startResendCooldown(int seconds) {
    _cooldownTimer?.cancel();
    setState(() => _resendSeconds = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_resendSeconds <= 1) {
        t.cancel();
        setState(() => _resendSeconds = 0);
        return;
      }
      setState(() => _resendSeconds--);
    });
  }

  String _otpString() => _otpControllers.map((c) => c.text).join();

  void _clearOtpFields() {
    for (final c in _otpControllers) {
      c.clear();
    }
  }

  void _onOtpDigitChanged(int index, String value) {
    final digit = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digit.isEmpty) {
      _otpControllers[index].text = '';
      return;
    }
    final char = digit.substring(digit.length - 1);
    _otpControllers[index].text = char;
    if (index < 5) {
      _otpFocusNodes[index + 1].requestFocus();
    } else {
      _otpFocusNodes[index].unfocus();
    }
    setState(() {});
  }

  Future<void> _onGoogleTap() => performClinovaGoogleSignIn(ref, context);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final authState = ref.watch(authControllerProvider);
    final auth = ref.read(authControllerProvider.notifier);
    final theme = Theme.of(context);
    final inInlineOtpStep =
        authState.stage == AuthStage.codeSent &&
        authState.otpIntent == OtpIntent.emailPasswordSecondFactor;

    ref.listen<AuthState>(authControllerProvider, (prev, next) {
      final enteredInlineOtpStep =
          !inInlineOtpStep &&
          next.stage == AuthStage.codeSent &&
          next.otpIntent == OtpIntent.emailPasswordSecondFactor;
      if (enteredInlineOtpStep) {
        _clearOtpFields();
        _startResendCooldown(60);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _otpFocusNodes.first.requestFocus();
          }
        });
      }
    });

    return AuthScaffold(
      leading: IconButton.filledTonal(
        onPressed: () => popOrGo(context, '/welcome'),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ClinovaLogo(size: 52, variant: LogoVariant.glass),
          const SizedBox(height: 16),
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
          const SizedBox(height: 20),
          AuthFormCard(
            child: inInlineOtpStep
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _teal.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shield_outlined, size: 18, color: _teal),
                            const SizedBox(width: 8),
                            Text(
                              l10n.authOtpExtraSecurityBadge,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: const Color(0xFF0F766E),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        l10n.authVerifyEmailBody(
                          authState.pendingEmail ?? emailController.text.trim(),
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: _muted,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(6, (i) {
                          return SizedBox(
                            width: 46,
                            child: TextField(
                              controller: _otpControllers[i],
                              focusNode: _otpFocusNodes[i],
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              maxLength: 1,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: _navy,
                                fontWeight: FontWeight.w700,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: InputDecoration(
                                counterText: '',
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE6EEF8),
                                  ),
                                ),
                              ),
                              onChanged: (v) => _onOtpDigitChanged(i, v),
                              onTap: () {
                                _otpControllers[i].selection = TextSelection(
                                  baseOffset: 0,
                                  extentOffset: _otpControllers[i].text.length,
                                );
                              },
                            ),
                          );
                        }),
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
                                  final code = _otpString();
                                  if (code.length != 6) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(l10n.authOtpFieldLabel),
                                      ),
                                    );
                                    return;
                                  }
                                  auth.dismissError();
                                  await auth.verifyOtp(code);
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
                              : Text(l10n.authVerifyContinue),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 18,
                            color: _primaryBlue,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _resendSeconds > 0
                                ? Text(
                                    l10n.authResendIn(
                                      '00:${_resendSeconds.toString().padLeft(2, '0')}',
                                    ),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: _primaryBlue,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  )
                                : TextButton(
                                    onPressed: authState.isBusy
                                        ? null
                                        : () async {
                                            auth.dismissError();
                                            _clearOtpFields();
                                            _otpFocusNodes.first.requestFocus();
                                            await auth.resendOtpCode();
                                            if (context.mounted) {
                                              _startResendCooldown(60);
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    l10n.authNewCodeSent,
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                    child: Text(l10n.authResendCode),
                                  ),
                          ),
                        ],
                      ),
                      const Divider(height: 28),
                      Center(
                        child: TextButton(
                          onPressed: authState.isBusy
                              ? null
                              : () {
                                  auth.prepareFreshCredentialFlow();
                                  _clearOtpFields();
                                  _cooldownTimer?.cancel();
                                  setState(() => _resendSeconds = 60);
                                },
                          child: Text(l10n.authChangeEmail),
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: InputDecoration(
                          labelText: l10n.authEmailLabel,
                          hintText: 'you@email.com',
                          prefixIcon: const Icon(Icons.mail_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
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
                      const SizedBox(height: 8),
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
                                  final err = _validateEmail(
                                    emailController.text,
                                    l10n,
                                  );
                                  if (err != null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(err)),
                                    );
                                    return;
                                  }
                                  if (passwordController.text.length < 8) {
                                    ScaffoldMessenger.of(context).showSnackBar(
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
                          onPressed: authState.isBusy ? null : _onGoogleTap,
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
              Text(l10n.authNewTo, style: theme.textTheme.bodyMedium),
              TextButton(
                onPressed: () => context.push('/auth/register'),
                child: Text(l10n.profileCreateAccount),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
