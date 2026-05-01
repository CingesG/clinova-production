import 'dart:async';

import 'package:diplom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  static const _primaryBlue = Color(0xFF1769FF);
  static const _navy = Color(0xFF071B4D);
  static const _muted = Color(0xFF64748B);
  static const _teal = Color(0xFF0EA5A4);

  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();
  final _otpControllers = List.generate(6, (_) => TextEditingController());
  final _otpFocusNodes = List.generate(6, (_) => FocusNode());
  Timer? _cooldownTimer;
  int _resendSeconds = 60;
  bool obscurePassword = true;
  bool obscureConfirm = true;

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    _cooldownTimer?.cancel();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final authState = ref.watch(authControllerProvider);
    final auth = ref.read(authControllerProvider.notifier);
    final theme = Theme.of(context);
    final inInlineOtpStep =
        authState.stage == AuthStage.codeSent &&
        authState.otpIntent == OtpIntent.register;

    ref.listen<AuthState>(authControllerProvider, (prev, next) {
      final enteredInlineOtpStep =
          !inInlineOtpStep &&
          next.stage == AuthStage.codeSent &&
          next.otpIntent == OtpIntent.register;
      if (enteredInlineOtpStep) {
        _clearOtpFields();
        _startResendCooldown(60);
        if (context.mounted) {
          final loc = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(loc.authRegisterCheckEmailSnack)),
          );
        }
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
                            Icon(
                              Icons.mail_outline_rounded,
                              size: 18,
                              color: _teal,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l10n.authRegisterCheckEmailSnack,
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
                                        content: Text(
                                          l10n.valEmailInvalidShort,
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  final p = passwordController.text;
                                  if (p.length < 8) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(l10n.valPasswordShort),
                                      ),
                                    );
                                    return;
                                  }
                                  if (p != confirmController.text) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(l10n.valPasswordsNoMatch),
                                      ),
                                    );
                                    return;
                                  }
                                  auth.dismissError();
                                  await auth.registerWithPassword(
                                    email: em,
                                    password: p,
                                    firstName: fn,
                                    lastName: ln,
                                  );
                                  if (!context.mounted) return;
                                  final nextState = ref.read(
                                    authControllerProvider,
                                  );
                                  final error =
                                      nextState.errorMessage?.toLowerCase() ??
                                      '';
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
