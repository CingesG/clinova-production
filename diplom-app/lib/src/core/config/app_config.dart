import '../../../config/env.dart';

/// Backward-compatible config wrapper around `Env`.
class AppConfig {
  static const googleClientId = Env.googleClientId;
  static const apiBaseUrl = Env.apiBaseUrl;
  static const realtimeBaseUrl = Env.realtimeBaseUrl;
}
