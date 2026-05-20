import 'package:dio/dio.dart';

import '../auth/auth_debug_log.dart';
import '../config/app_config.dart';
import '../storage/token_storage.dart';

/// Single in-flight refresh so parallel 401s share one [POST /auth/refresh].
Future<bool>? _coordinatedRefresh;

/// Calls [POST /auth/refresh] with a standalone [Dio] (no auth interceptors).
/// Persists new access (and refresh when rotated) to [storage].
Future<bool> tryRefreshClinovaTokens(TokenStorage storage) async {
  final refresh = await storage.readRefreshToken();
  if (refresh == null || refresh.isEmpty) {
    return false;
  }
  try {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
    final res = await dio
        .post<Map<String, dynamic>>(
          '/auth/refresh',
          data: {'refreshToken': refresh},
        )
        .timeout(const Duration(seconds: 10));
    final data = res.data;
    if (data == null) return false;
    final access = data['accessToken']?.toString() ?? '';
    final newRefresh = data['refreshToken']?.toString() ?? '';
    if (access.isEmpty) return false;
    authDebugLog('auth storage write started (refresh endpoint)');
    await storage.saveToken(access);
    authDebugLog('access token saved');
    if (newRefresh.isNotEmpty) {
      await storage.saveRefreshToken(newRefresh);
      authDebugLog('refresh token saved');
    }
    return true;
  } catch (_) {
    return false;
  }
}

/// Deduplicates concurrent refresh attempts (e.g. many API calls 401 at once).
Future<bool> refreshClinovaTokensCoordinated(TokenStorage storage) {
  if (_coordinatedRefresh != null) {
    return _coordinatedRefresh!;
  }
  _coordinatedRefresh = tryRefreshClinovaTokens(storage).whenComplete(() {
    _coordinatedRefresh = null;
  });
  return _coordinatedRefresh!;
}
