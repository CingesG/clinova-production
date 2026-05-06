import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_controller.dart';
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
        final token = await storage.readToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
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
          ref.read(authControllerProvider.notifier).handleUnauthorized();
          handler.next(error);
          return;
        }

        final ok = await refreshClinovaTokensCoordinated(storage);
        if (!ok) {
          ref.read(authControllerProvider.notifier).handleUnauthorized();
          handler.next(error);
          return;
        }

        final newToken = await storage.readToken();
        if (newToken == null || newToken.isEmpty) {
          ref.read(authControllerProvider.notifier).handleUnauthorized();
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
        } catch (_) {
          ref.read(authControllerProvider.notifier).handleUnauthorized();
          handler.next(error);
        }
      },
    ),
  );

  return dio;
});
