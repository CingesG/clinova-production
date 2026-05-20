import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_debug_log.dart';
import 'token_storage.dart';
import 'web_token_storage_export.dart';

/// Migrates tokens from legacy stores into [WebLocalStorageTokenStorage].
Future<void> migrateWebTokensFromSecureStorageIfNeeded(
  TokenStorage storage,
) async {
  if (!kIsWeb || storage is! WebLocalStorageTokenStorage) return;

  final existing = await storage.readToken();
  if (existing != null && existing.isNotEmpty) return;

  // Legacy SharedPreferences (flutter.* prefix).
  try {
    final prefs = await SharedPreferences.getInstance();
    final fromPrefsAccess = prefs.getString('clinova_access_token');
    final fromPrefsRefresh = prefs.getString('clinova_refresh_token');
    if (fromPrefsAccess != null && fromPrefsAccess.isNotEmpty) {
      authDebugLog('migrating tokens from SharedPreferences');
      await storage.saveToken(fromPrefsAccess);
      if (fromPrefsRefresh != null && fromPrefsRefresh.isNotEmpty) {
        await storage.saveRefreshToken(fromPrefsRefresh);
      }
      return;
    }
  } catch (_) {}

  // Legacy FlutterSecureStorage.
  const legacy = FlutterSecureStorage();
  try {
    final access = await legacy.read(key: WebLocalStorageTokenStorage.accessTokenKey);
    final refresh = await legacy.read(key: WebLocalStorageTokenStorage.refreshTokenKey);
    if (access != null && access.isNotEmpty) {
      authDebugLog('migrating tokens from FlutterSecureStorage');
      await storage.saveToken(access);
      if (refresh != null && refresh.isNotEmpty) {
        await storage.saveRefreshToken(refresh);
      }
    }
  } catch (_) {}
}
