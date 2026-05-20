import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_controller.dart';

/// On web/tab resume: silently refresh session without returning to splash.
class AuthLifecycleScope extends ConsumerStatefulWidget {
  const AuthLifecycleScope({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AuthLifecycleScope> createState() => _AuthLifecycleScopeState();
}

class _AuthLifecycleScopeState extends ConsumerState<AuthLifecycleScope>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(authControllerProvider.notifier).resumeSessionCheck();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
