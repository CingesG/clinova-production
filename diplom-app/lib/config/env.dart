/// Compile-time configuration via `--dart-define=KEY=value`.
///
/// Production web builds must pass `API_BASE_URL` (see `tool/vercel_flutter_build.sh`, `tool/build_web_release.sh`).
/// Local/API override: `--dart-define=API_BASE_URL=http://localhost:4000`.
/// Web Google Sign-In / Firebase expect `GOOGLE_CLIENT_ID` and `FIREBASE_WEB_*` when used on web.
class Env {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://clinova-api-production.onrender.com',
  );

  static const String realtimeBaseUrl = String.fromEnvironment(
    'REALTIME_BASE_URL',
    defaultValue: apiBaseUrl,
  );

  /// Web/mobile release: pass `--dart-define=GOOGLE_CLIENT_ID=...` (OAuth **Web** client ID).
  static const String googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue: '',
  );

  // Optional web Firebase config for production web/PWA.
  static const String firebaseWebApiKey = String.fromEnvironment(
    'FIREBASE_WEB_API_KEY',
    defaultValue: '',
  );
  static const String firebaseWebAuthDomain = String.fromEnvironment(
    'FIREBASE_WEB_AUTH_DOMAIN',
    defaultValue: '',
  );
  static const String firebaseWebProjectId = String.fromEnvironment(
    'FIREBASE_WEB_PROJECT_ID',
    defaultValue: '',
  );
  static const String firebaseWebStorageBucket = String.fromEnvironment(
    'FIREBASE_WEB_STORAGE_BUCKET',
    defaultValue: '',
  );
  static const String firebaseWebMessagingSenderId = String.fromEnvironment(
    'FIREBASE_WEB_MESSAGING_SENDER_ID',
    defaultValue: '',
  );
  static const String firebaseWebAppId = String.fromEnvironment(
    'FIREBASE_WEB_APP_ID',
    defaultValue: '',
  );
  static const String firebaseWebMeasurementId = String.fromEnvironment(
    'FIREBASE_WEB_MEASUREMENT_ID',
    defaultValue: '',
  );
}
