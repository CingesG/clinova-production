import 'token_storage.dart';

/// Non-web builds only (conditional import fallback).
class WebLocalStorageTokenStorage implements TokenStorage {
  static const accessTokenKey = 'clinova_access_token';
  static const refreshTokenKey = 'clinova_refresh_token';
  static const sessionUserKey = 'clinova_auth_user';

  @override
  Future<void> clearAll() async {}

  @override
  Future<void> clearToken() async {}

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<String?> readToken() async => null;

  @override
  Future<void> saveRefreshToken(String token) async {}

  @override
  Future<void> saveToken(String token) async {}

  Future<void> saveSessionUser(Map<String, dynamic> user) async {}

  Map<String, dynamic>? readSessionUser() => null;
}
