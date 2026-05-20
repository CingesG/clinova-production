import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_controller.dart';
import '../auth/auth_debug_log.dart';
import '../config/app_config.dart';
import '../storage/token_storage.dart';
import 'token_refresh.dart';

/// 401 here means invalid credentials or email — not an expired access token.
bool _isAuthCredentialPath(String path) {
  const paths = {
    '/auth/password-login',
    '/auth/register',
    '/auth/verify-otp',
    '/auth/verify-email',
    '/auth/resend-verification',
    '/auth/resend-login-otp',
    '/auth/request-otp',
    '/auth/forgot-password',
    '/auth/reset-password',
    '/auth/google',
    '/auth/refresh',
  };
  return paths.contains(path);
}

final apiClientProvider = Provider<Dio>((ref) {
  final storage = ref.watch(tokenStorageProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (!_isAuthCredentialPath(options.path)) {
          try {
            final token = await storage
                .readToken()
                .timeout(const Duration(seconds: 5), onTimeout: () => null);
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          } catch (_) {
            // Proceed without Authorization; server may return 401.
          }
        } else {
          options.headers.remove('Authorization');
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final status = error.response?.statusCode;
        if (status != 401) {
          handler.next(error);
          return;
        }

        final opts = error.requestOptions;
        final authHeader = opts.headers['Authorization']?.toString() ?? '';
        if (!authHeader.startsWith('Bearer ')) {
          handler.next(error);
          return;
        }

        if (_isAuthCredentialPath(opts.path)) {
          handler.next(error);
          return;
        }

        if (opts.extra['retryAfterRefresh'] == true) {
          await ref.read(authControllerProvider.notifier).handleUnauthorized();
          handler.next(error);
          return;
        }

        final ok = await refreshClinovaTokensCoordinated(storage);
        if (!ok) {
          await ref.read(authControllerProvider.notifier).handleUnauthorized();
          handler.next(error);
          return;
        }

        final newToken = await storage.readToken();
        if (newToken == null || newToken.isEmpty) {
          await ref.read(authControllerProvider.notifier).handleUnauthorized();
          handler.next(error);
          return;
        }

        ref
            .read(authControllerProvider.notifier)
            .applyRefreshedAccessToken(newToken);

        opts.headers['Authorization'] = 'Bearer $newToken';
        opts.extra['retryAfterRefresh'] = true;

        try {
          final response = await dio.fetch<dynamic>(opts);
          handler.resolve(response);
        } catch (retryError) {
          authDebugLog('retry after refresh failed for ${opts.path}');
          await ref.read(authControllerProvider.notifier).handleUnauthorized();
          if (retryError is DioException) {
            handler.next(retryError);
          } else {
            handler.next(error);
          }
        }
      },
    ),
  );

  return dio;
});
