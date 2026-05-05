import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/context_l10n.dart';
import '../../../core/navigation/go_router_pop.dart';
import '../../../core/network/clinova_api.dart';
import '../../../core/widgets/clinova_backdrop.dart';
import '../../auth/application/auth_controller.dart';

class ProfileChangePasswordScreen extends ConsumerStatefulWidget {
  const ProfileChangePasswordScreen({super.key});

  @override
  ConsumerState<ProfileChangePasswordScreen> createState() =>
      _ProfileChangePasswordScreenState();
}

class _ProfileChangePasswordScreenState
    extends ConsumerState<ProfileChangePasswordScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _obCurrent = true;
  bool _obNext = true;
  bool _obConfirm = true;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _serverMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return null;
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    if (_busy) return;

    final cur = _current.text;
    final nw = _next.text;
    final cf = _confirm.text;
    if (cur.isEmpty || nw.isEmpty || cf.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.profileChangePasswordGenericError)),
      );
      return;
    }
    if (nw.length < 8) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.profileChangePasswordTooShort)),
      );
      return;
    }
    if (nw != cf) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.profileChangePasswordMismatch)),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(clinovaApiProvider).changeMyPassword(
            currentPassword: cur,
            newPassword: nw,
          );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.profileChangePasswordSuccessSnack)),
      );
      context.pop();
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = _serverMessage(e) ?? l10n.profileChangePasswordGenericError;
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final user = ref.watch(authControllerProvider).user;

    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/welcome');
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileChangePasswordTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => popOrGo(context, '/profile'),
        ),
      ),
      body: ClinovaBackdrop(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Text(
              l10n.profileChangePasswordSubtitle,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              user.email,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _current,
              obscureText: _obCurrent,
              decoration: InputDecoration(
                labelText: l10n.profileChangePasswordCurrentLabel,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obCurrent ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(() => _obCurrent = !_obCurrent),
                ),
              ),
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.password],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _next,
              obscureText: _obNext,
              decoration: InputDecoration(
                labelText: l10n.profileChangePasswordNewLabel,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obNext ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(() => _obNext = !_obNext),
                ),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirm,
              obscureText: _obConfirm,
              decoration: InputDecoration(
                labelText: l10n.profileChangePasswordConfirmLabel,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(() => _obConfirm = !_obConfirm),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.profileChangePasswordSubmit),
            ),
          ],
        ),
      ),
    );
  }
}
