import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'web_token_storage_export.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  if (kIsWeb) {
    return WebLocalStorageTokenStorage();
  }
  return SecureTokenStorage();
});

/// Web-only: cache user snapshot in localStorage (see [WebLocalStorageTokenStorage]).
void persistWebSessionUser(TokenStorage storage, Map<String, dynamic> user) {
  if (!kIsWeb) return;
  final web = storage;
  if (web is WebLocalStorageTokenStorage) {
    web.saveSessionUser(user);
  }
}

abstract class TokenStorage {
  Future<String?> readToken();

  Future<void> saveToken(String token);

  Future<String?> readRefreshToken();

  Future<void> saveRefreshToken(String token);

  Future<void> clearToken();

  Future<void> clearAll();
}

class SecureTokenStorage implements TokenStorage {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'clinova_access_token';
  static const _refreshKey = 'clinova_refresh_token';

  @override
  Future<void> saveToken(String token) {
    return _storage.write(key: _tokenKey, value: token);
  }

  @override
  Future<String?> readToken() {
    return _storage.read(key: _tokenKey);
  }

  @override
  Future<void> saveRefreshToken(String token) {
    return _storage.write(key: _refreshKey, value: token);
  }

  @override
  Future<String?> readRefreshToken() {
    return _storage.read(key: _refreshKey);
  }

  @override
  Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
  }

  @override
  Future<void> clearAll() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _refreshKey);
  }
}

/// For tests; avoids platform secure storage.
class InMemoryTokenStorage implements TokenStorage {
  String? _token;
  String? _refresh;

  @override
  Future<void> clearAll() async {
    _token = null;
    _refresh = null;
  }

  @override
  Future<void> clearToken() async {
    _token = null;
  }

  @override
  Future<String?> readRefreshToken() async => _refresh;

  @override
  Future<String?> readToken() async => _token;

  @override
  Future<void> saveRefreshToken(String token) async {
    _refresh = token;
  }

  @override
  Future<void> saveToken(String token) async {
    _token = token;
  }
}
