import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Dashboard path for a signed-in user (patient shell vs doctor vs admin).
String clinovaAuthenticatedHome(String? role) {
  switch (role) {
    case 'ADMIN':
    case 'STAFF':
      return '/admin';
    case 'DOCTOR':
      return '/doctor';
    default:
      return '/home';
  }
}

/// Use with [popOrGo] when the stack may be empty (deep link). Guests typically use [guestFallback] `/welcome`.
String clinovaNavigationFallback({
  required bool isAuthenticated,
  String? role,
  String guestFallback = '/welcome',
}) {
  if (!isAuthenticated) return guestFallback;
  return clinovaAuthenticatedHome(role);
}

/// Pops the GoRouter page stack when possible; otherwise **[location]** (no throw).
///
/// Use instead of raw [GoRouter.pop] / [BuildContext.pop] for top-level screens that
/// may be the first history entry (e.g. opened via deep link `/#/path`).
void popOrGo(BuildContext context, String location) {
  final router = GoRouter.of(context);
  if (!router.canPop()) {
    router.go(location);
    return;
  }
  try {
    router.pop();
  } on GoError {
    router.go(location);
  }
}

/// Pops the nearest [Navigator] overlay (dialog, modal route) when possible.
void safeNavigatorPop(BuildContext context, {VoidCallback? orElse}) {
  final nav = Navigator.maybeOf(context);
  if (nav != null && nav.canPop()) {
    nav.pop();
    return;
  }
  orElse?.call();
}
