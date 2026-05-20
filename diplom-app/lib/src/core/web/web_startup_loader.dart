import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Hides the HTML `#clinova-startup-loader` shown in [web/index.html] before Flutter paints.
void hideWebHtmlStartupLoader() {
  if (!kIsWeb) return;
  try {
    web.window.dispatchEvent(web.Event('flutter-first-frame'));
  } catch (_) {}
}
