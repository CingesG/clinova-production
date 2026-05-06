import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

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
