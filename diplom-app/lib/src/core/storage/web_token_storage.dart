import 'dart:convert';

import 'package:web/web.dart' as web;

import '../auth/auth_debug_log.dart';
import 'token_storage.dart';

/// Primary Flutter **web** auth persistence via `window.localStorage`.
///
/// Keys (visible in DevTools → Application → Local storage):
/// - [accessTokenKey]
/// - [refreshTokenKey]
/// - [sessionUserKey] (optional cached user snapshot)
class WebLocalStorageTokenStorage implements TokenStorage {
  static const accessTokenKey = 'clinova_access_token';
  static const refreshTokenKey = 'clinova_refresh_token';
  static const sessionUserKey = 'clinova_auth_user';

  String? _get(String key) {
    final v = web.window.localStorage.getItem(key);
    return (v == null || v.isEmpty) ? null : v;
  }

  void _set(String key, String value) {
    web.window.localStorage.setItem(key, value);
  }

  void _remove(String key) {
    web.window.localStorage.removeItem(key);
  }

  void _verifyWrite(String key, String expected) {
    final got = _get(key);
    if (got != expected) {
      authDebugLog('storage verify FAILED for $key (len=${got?.length ?? 0})');
    }
  }

  @override
  Future<String?> readToken() async => _get(accessTokenKey);

  @override
  Future<void> saveToken(String token) async {
    authDebugLog('token save started (access)');
    _set(accessTokenKey, token);
    _verifyWrite(accessTokenKey, token);
    authDebugLog('accessToken saved');
  }

  @override
  Future<String?> readRefreshToken() async => _get(refreshTokenKey);

  @override
  Future<void> saveRefreshToken(String token) async {
    authDebugLog('token save started (refresh)');
    _set(refreshTokenKey, token);
    _verifyWrite(refreshTokenKey, token);
    authDebugLog('refreshToken saved');
  }

  @override
  Future<void> clearToken() async {
    _remove(accessTokenKey);
  }

  @override
  Future<void> clearAll() async {
    _remove(accessTokenKey);
    _remove(refreshTokenKey);
    _remove(sessionUserKey);
    authDebugLog('auth storage cleared');
  }

  /// Cached user from last login (not required for API; helps debugging).
  Future<void> saveSessionUser(Map<String, dynamic> user) async {
    try {
      _set(sessionUserKey, jsonEncode(user));
    } catch (_) {}
  }

  Map<String, dynamic>? readSessionUser() {
    final raw = _get(sessionUserKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return null;
  }
}
