import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// [GoRouter.canPop] and [GoRouter.pop] can disagree; avoid a runtime [GoError].
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
