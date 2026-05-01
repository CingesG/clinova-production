import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/context_l10n.dart';
import '../../../core/widgets/clinova_backdrop.dart';
import '../../../core/widgets/clinova_logo.dart';
import '../application/auth_controller.dart';
import 'auth_ui.dart';

class VerifyOtpScreen extends ConsumerStatefulWidget {
  const VerifyOtpScreen({super.key});

  @override
  ConsumerState<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends ConsumerState<VerifyOtpScreen> {
  static const _primaryBlue = Color(0xFF1769FF);
  static const _navy = Color(0xFF071B4D);
  static const _muted = Color(0xFF64748B);
  static const _teal = Color(0xFF0EA5A4);

  final _controllers = List.generate(6, (_) => TextEditingController());
  final _focusNodes = List.generate(6, (_) => FocusNode());
  Timer? _cooldownTimer;
  int _resendSeconds = 60;

  @override
  void initState() {
    super.initState();
    _startResendCooldown(60);
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

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String _otpString() => _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    final digit = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digit.isEmpty) {
      _controllers[index].text = '';
      return;
    }
    final char = digit.substring(digit.length - 1);
    _controllers[index].text = char;
    if (index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else {
      _focusNodes[index].unfocus();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final authState = ref.watch(authControllerProvider);
    final auth = ref.read(authControllerProvider.notifier);
    final theme = Theme.of(context);
    final email = authState.pendingEmail ?? '';

    return Scaffold(
      body: ClinovaBackdrop(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: () {
                        auth.prepareFreshCredentialFlow();
                        context.go('/auth/login');
                      },
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  TextButton.icon(
                    onPressed: () {
                      auth.prepareFreshCredentialFlow();
                      context.go('/auth/login');
                    },
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: Text(l10n.authVerifyBackToLogin),
                  ),
                  const ClinovaLogo(
                    size: 46,
                    variant: LogoVariant.glass,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.authVerifyEmailTitle,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: _navy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    email.isEmpty
                        ? l10n.authVerifyEmailMissing
                        : l10n.authVerifyEmailBody(email),
                    style: theme.textTheme.bodyLarge?.copyWith(color: _muted),
                  ),
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 20),
                  AuthFormCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.authVerifyFormTitle,
                          style: theme.textTheme.titleSmall?.copyWith(
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
                                controller: _controllers[i],
                                focusNode: _focusNodes[i],
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
                                onChanged: (v) => _onDigitChanged(i, v),
                                onTap: () {
                                  _controllers[i].selection = TextSelection(
                                    baseOffset: 0,
                                    extentOffset: _controllers[i].text.length,
                                  );
                                },
                              ),
                            );
                          }),
                        ),
                        if (authState.debugCode != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              l10n.authDevCode(authState.debugCode!),
                              style: const TextStyle(
                                color: Color(0xFF0C4A6E),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
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
                            onPressed: authState.isBusy || email.isEmpty
                                ? null
                                : () async {
                                    final code = _otpString();
                                    if (code.length != 6) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
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
                            Icon(Icons.schedule_rounded,
                                size: 18, color: _primaryBlue),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _resendSeconds > 0
                                  ? Text(
                                      l10n.authResendIn(
                                        '00:${_resendSeconds.toString().padLeft(2, '0')}',
                                      ),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                        color: _primaryBlue,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    )
                                  : TextButton(
                                      onPressed: authState.isBusy || email.isEmpty
                                          ? null
                                          : () async {
                                              auth.dismissError();
                                              for (final c in _controllers) {
                                                c.clear();
                                              }
                                              _focusNodes.first.requestFocus();
                                              await auth.resendOtpCode();
                                              if (context.mounted) {
                                                _startResendCooldown(60);
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
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
                        const Divider(height: 32),
                        Center(
                          child: TextButton(
                            onPressed: () {
                              auth.prepareFreshCredentialFlow();
                              context.go('/auth/login');
                            },
                            child: Text(l10n.authChangeEmail),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.shield_outlined,
                          size: 18, color: _muted.withValues(alpha: 0.85)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.authOtpProtectionNote,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    color: const Color(0xFFF6FAFF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0xFFE6EEF8)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const Text(
                            'G',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF4285F4),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              l10n.authOtpGoogleHint,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: _muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
