import 'package:flutter/foundation.dart';

/// Startup/auth/router diagnostics (debug builds only).
void authDebugLog(String message) {
  if (kDebugMode) {
    debugPrint('[ClinovaAuth] $message');
  }
}
