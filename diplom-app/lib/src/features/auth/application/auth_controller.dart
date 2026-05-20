import 'dart:async';

import 'package:dio/dio.dart';
import 'package:diplom_app/l10n/app_localizations.dart';
import 'package:diplom_app/l10n/app_localizations_en.dart';
import 'package:diplom_app/l10n/app_localizations_mn.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_debug_log.dart';
import '../../../core/network/clinova_api.dart';
import '../../../core/network/token_refresh.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/storage/web_token_migration.dart';
import 'package:flutter/foundation.dart';
import '../../settings/presentation/language_controller.dart';
import '../domain/app_user.dart';

enum AuthStage { bootstrapping, signedOut, codeSent, signedIn }

enum OtpIntent {
  signInCode,
  register,
  forgotPassword,
  /// Finish registration or verify email after password login returned EMAIL_NOT_VERIFIED.
  emailVerification,
}

class AuthState {
  const AuthState({
    required this.stage,
    this.user,
    this.token,
    this.pendingEmail,
    this.pendingFirstName,
    this.pendingLastName,
    this.pendingPasswordForOtp,
    this.otpIntent,
    this.debugCode,
    this.errorMessage,
    this.isBusy = false,
    this.sessionRestorePending = false,
  });

  final AuthStage stage;
  final AppUser? user;
  final String? token;
  /// Web: stay on splash while reading storage / calling /auth/me (UI paints first).
  final bool sessionRestorePending;
  final String? pendingEmail;
  final String? pendingFirstName;
  final String? pendingLastName;
  /// Short-lived: reserved for flows that needed password to resend (login OTP removed).
  final String? pendingPasswordForOtp;
  final OtpIntent? otpIntent;
  final String? debugCode;
  final String? errorMessage;
  final bool isBusy;

  bool get isAuthenticated => stage == AuthStage.signedIn && user != null;
  bool get isBootstrapping => stage == AuthStage.bootstrapping;
  bool get isCodeStep => stage == AuthStage.codeSent;

  AuthState copyWith({
    AuthStage? stage,
    AppUser? user,
    String? token,
    String? pendingEmail,
    String? pendingFirstName,
    String? pendingLastName,
    String? pendingPasswordForOtp,
    OtpIntent? otpIntent,
    String? debugCode,
    String? errorMessage,
    bool? isBusy,
    bool? sessionRestorePending,
    bool clearUser = false,
    bool clearToken = false,
    bool clearPendingEmail = false,
    bool clearPendingRegisterNames = false,
    bool clearPendingPasswordForOtp = false,
    bool clearOtpIntent = false,
    bool clearDebugCode = false,
    bool clearError = false,
  }) {
    return AuthState(
      stage: stage ?? this.stage,
      user: clearUser ? null : user ?? this.user,
      token: clearToken ? null : token ?? this.token,
      pendingEmail: clearPendingEmail
          ? null
          : pendingEmail ?? this.pendingEmail,
      pendingFirstName: clearPendingRegisterNames
          ? null
          : pendingFirstName ?? this.pendingFirstName,
      pendingLastName: clearPendingRegisterNames
          ? null
          : pendingLastName ?? this.pendingLastName,
      pendingPasswordForOtp: clearPendingPasswordForOtp
          ? null
          : pendingPasswordForOtp ?? this.pendingPasswordForOtp,
      otpIntent: clearOtpIntent ? null : otpIntent ?? this.otpIntent,
      debugCode: clearDebugCode ? null : debugCode ?? this.debugCode,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      isBusy: isBusy ?? this.isBusy,
      sessionRestorePending:
          sessionRestorePending ?? this.sessionRestorePending,
    );
  }

  factory AuthState.initial() {
    if (kIsWeb) {
      return const AuthState(
        stage: AuthStage.signedOut,
        sessionRestorePending: true,
      );
    }
    return const AuthState(stage: AuthStage.bootstrapping);
  }

  /// Router keeps user on [/splash] while session is restored (non-blocking UI).
  bool get holdsSplashDuringStartup =>
      isBootstrapping || sessionRestorePending;
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    final controller = AuthController(ref);
    controller.bootstrap();
    return controller;
  },
);

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._ref) : super(AuthState.initial());

  final Ref _ref;
  bool _bootstrapped = false;
  bool _resumeCheckInFlight = false;

  static const _bootstrapTimeout = Duration(seconds: 10);
  static const _apiCallTimeout = Duration(seconds: 9);
  static const _storageReadTimeout = Duration(seconds: 5);

  void _setSignedOut() {
    state = state.copyWith(
      stage: AuthStage.signedOut,
      isBusy: false,
      clearToken: true,
      clearUser: true,
      clearPendingEmail: true,
      clearPendingRegisterNames: true,
      clearPendingPasswordForOtp: true,
      clearOtpIntent: true,
      clearDebugCode: true,
      clearError: true,
    );
  }

  Future<void> _safeClearStorage(TokenStorage storage) async {
    try {
      await storage.clearAll().timeout(
        _storageReadTimeout,
        onTimeout: () {},
      );
    } catch (_) {}
  }

  bool _isValidUserPayload(Map<String, dynamic>? json) {
    if (json == null) return false;
    final id = json['id']?.toString().trim() ?? '';
    return id.isNotEmpty;
  }

  /// Guarantees startup never ends on [AuthStage.bootstrapping] or stuck [isBusy].
  void _ensureBootstrapResolved() {
    if (state.stage == AuthStage.bootstrapping) {
      authDebugLog('bootstrap guard: still bootstrapping -> signedOut');
      _setSignedOut();
      return;
    }
    if (state.stage == AuthStage.signedIn &&
        (state.user == null ||
            state.user!.id.isEmpty ||
            state.token == null ||
            state.token!.isEmpty)) {
      authDebugLog('bootstrap guard: incomplete signedIn -> signedOut');
      _setSignedOut();
      return;
    }
    if (state.isBusy) {
      state = state.copyWith(isBusy: false);
    }
  }

  Future<String?> _readAccessToken(TokenStorage storage) async {
    try {
      return await storage
          .readToken()
          .timeout(_storageReadTimeout, onTimeout: () => null);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _fetchMe() async {
    try {
      return await _ref
          .read(clinovaApiProvider)
          .me()
          .timeout(_apiCallTimeout);
    } on TimeoutException {
      authDebugLog('/auth/me timeout');
      return null;
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401) {
        authDebugLog('/auth/me 401');
      } else {
        authDebugLog('/auth/me ${code ?? e.type}');
      }
      return null;
    } catch (_) {
      authDebugLog('/auth/me failed');
      return null;
    }
  }

  Future<bool> _tryRefreshSession(TokenStorage storage) async {
    authDebugLog('refresh started');
    try {
      final ok = await refreshClinovaTokensCoordinated(storage)
          .timeout(_bootstrapTimeout, onTimeout: () => false);
      if (ok) {
        authDebugLog('refresh success');
      } else {
        authDebugLog('refresh failed');
      }
      return ok;
    } catch (_) {
      authDebugLog('refresh failed');
      return false;
    }
  }

  /// Returns true when session is [AuthStage.signedIn].
  Future<bool> _applySignedIn(
    String token,
    Map<String, dynamic> userJson,
    TokenStorage storage,
  ) async {
    try {
      if (token.isEmpty || !_isValidUserPayload(userJson)) {
        throw const FormatException('Invalid session payload');
      }
      state = state.copyWith(
        stage: AuthStage.signedIn,
        token: token,
        user: AppUser.fromJson(userJson),
        isBusy: false,
        clearPendingEmail: true,
        clearPendingRegisterNames: true,
        clearPendingPasswordForOtp: true,
        clearOtpIntent: true,
        clearDebugCode: true,
        clearError: true,
      );
      authDebugLog('auth state changed -> signedIn');
      return true;
    } catch (e) {
      authDebugLog('signedIn apply failed: $e');
      await _safeClearStorage(storage);
      _setSignedOut();
      return false;
    }
  }

  Future<void> _restoreSessionFromToken(
    String token,
    TokenStorage storage,
  ) async {
    try {
      var access = token;
      var userJson = await _fetchMe();
      if (userJson != null && _isValidUserPayload(userJson)) {
        authDebugLog('/auth/me success');
        if (await _applySignedIn(access, userJson, storage)) return;
      }

      authDebugLog('/auth/me failed — trying refresh once');
      final refreshed = await _tryRefreshSession(storage);
      if (refreshed) {
        access = await _readAccessToken(storage) ?? '';
        if (access.isNotEmpty) {
          userJson = await _fetchMe();
          if (userJson != null && _isValidUserPayload(userJson)) {
            authDebugLog('/auth/me success after refresh');
            if (await _applySignedIn(access, userJson, storage)) return;
          }
        }
      }

      await _safeClearStorage(storage);
      _setSignedOut();
      authDebugLog('auth state changed -> signedOut (session invalid)');
    } catch (e) {
      authDebugLog('restoreSessionFromToken error: $e');
      await _safeClearStorage(storage);
      _setSignedOut();
    }
  }

  Future<void> bootstrap() async {
    if (_bootstrapped) return;
    _bootstrapped = true;
    authDebugLog('auth init started');

    final storage = _ref.read(tokenStorageProvider);

    try {
      await _runBootstrap(storage).timeout(
        _bootstrapTimeout,
        onTimeout: () {
          authDebugLog('bootstrap timed out');
          throw TimeoutException('Auth bootstrap timed out');
        },
      );
    } catch (e) {
      authDebugLog('bootstrap error: $e');
      await _safeClearStorage(storage);
      _setSignedOut();
    } finally {
      state = state.copyWith(sessionRestorePending: false);
      _ensureBootstrapResolved();
      authDebugLog(
        'bootstrap finished stage=${state.stage.name} busy=${state.isBusy}',
      );
    }
  }

  Future<void> _runBootstrap(TokenStorage storage) async {
    try {
      await migrateWebTokensFromSecureStorageIfNeeded(storage).timeout(
        _storageReadTimeout,
        onTimeout: () {},
      );
    } catch (_) {}

    authDebugLog('startup auth read started');
    final token = await _readAccessToken(storage);
    if (token == null || token.isEmpty) {
      authDebugLog('token missing');
      _setSignedOut();
      return;
    }

    authDebugLog('token found');
    state = state.copyWith(token: token, isBusy: true, clearError: true);
    await _restoreSessionFromToken(token, storage);
  }

  /// Tab resume: refresh once if needed; never return to [AuthStage.bootstrapping].
  Future<void> resumeSessionCheck() async {
    if (_resumeCheckInFlight) return;
    if (state.stage != AuthStage.signedIn || state.token == null) return;

    _resumeCheckInFlight = true;
    final storage = _ref.read(tokenStorageProvider);
    try {
      final userJson = await _fetchMe();
      if (userJson != null) {
        state = state.copyWith(user: AppUser.fromJson(userJson));
        return;
      }
      final refreshed = await _tryRefreshSession(storage);
      if (!refreshed) {
        await storage.clearAll();
        _setSignedOut();
        return;
      }
      final access = await _readAccessToken(storage) ?? '';
      if (access.isEmpty) {
        await storage.clearAll();
        _setSignedOut();
        return;
      }
      final retry = await _fetchMe();
      if (retry != null) {
        state = state.copyWith(
          token: access,
          user: AppUser.fromJson(retry),
          stage: AuthStage.signedIn,
        );
      } else {
        await storage.clearAll();
        _setSignedOut();
      }
    } finally {
      _resumeCheckInFlight = false;
    }
  }

  /// Keeps in-memory [AuthState.token] aligned with secure storage after a silent refresh.
  void applyRefreshedAccessToken(String accessToken) {
    if (accessToken.isEmpty) return;
    if (state.stage == AuthStage.signedOut) return;
    state = state.copyWith(token: accessToken);
    authDebugLog('access token rotated in memory');
  }

  void prepareFreshCredentialFlow() {
    state = state.copyWith(
      stage: AuthStage.signedOut,
      clearUser: true,
      clearPendingEmail: true,
      clearPendingRegisterNames: true,
      clearPendingPasswordForOtp: true,
      clearOtpIntent: true,
      clearDebugCode: true,
      clearError: true,
    );
  }

  Future<void> _persistTokensFromResponse(Map<String, dynamic> response) async {
    final access = response['accessToken']?.toString() ?? '';
    final refresh = response['refreshToken']?.toString() ?? '';
    final storage = _ref.read(tokenStorageProvider);
    if (access.isEmpty) {
      authDebugLog('auth storage write skipped — empty accessToken');
      return;
    }
    authDebugLog('login success — token save started');
    await storage.saveToken(access);
    if (refresh.isNotEmpty) {
      await storage.saveRefreshToken(refresh);
    } else {
      authDebugLog('refreshToken missing in login response');
    }
    final rawUser = response['user'];
    if (rawUser is Map) {
      persistWebSessionUser(
        storage,
        Map<String, dynamic>.from(rawUser),
      );
    }
    if (kIsWeb) {
      final roundTrip = await storage.readToken();
      if (roundTrip != access) {
        authDebugLog(
          'WARNING: accessToken round-trip mismatch after save',
        );
      }
    }
  }

  /// Maps [AuthState.otpIntent] to the backend `purpose` for `POST /auth/verify-otp`.
  ///
  /// Registration / email verification uses [POST /auth/verify-email] instead.
  String _otpPurposeForVerify() {
    switch (state.otpIntent) {
      case OtpIntent.register:
      case OtpIntent.emailVerification:
        throw StateError(
          'Registration/email verification must use verify-email, not verify-otp.',
        );
      case OtpIntent.signInCode:
        return 'LOGIN';
      case OtpIntent.forgotPassword:
        throw StateError(
          'Password reset OTP must be submitted via reset-password, not verify-otp.',
        );
      case null:
        throw StateError('OTP intent is missing; restart the login or register flow.');
    }
  }

  AppLocalizations _lookupL10n() {
    final loc = _ref.read(languageControllerProvider);
    return loc.languageCode == 'en'
        ? AppLocalizationsEn()
        : AppLocalizationsMn();
  }

  /// Finishes sign-in after [passwordLogin] returned tokens (no OTP step).
  Future<void> _applySuccessfulPasswordLoginResponse(
    Map<String, dynamic> response,
  ) async {
    final token = response['accessToken']?.toString() ?? '';
    if (token.isEmpty) {
      state = state.copyWith(
        isBusy: false,
        errorMessage: 'Login response did not include a token. Try again.',
      );
      return;
    }
    await _persistTokensFromResponse(response);
    authDebugLog('password login tokens persisted');
    final user = AppUser.fromJson(
      response['user'] is Map<String, dynamic>
          ? response['user'] as Map<String, dynamic>
          : <String, dynamic>{},
    );
    try {
      await _verifyAccountWithBackend(user);
    } catch (e) {
      await _ref.read(tokenStorageProvider).clearAll();
      state = state.copyWith(
        stage: AuthStage.signedOut,
        isBusy: false,
        clearToken: true,
        clearUser: true,
        clearPendingPasswordForOtp: true,
        errorMessage: e is DioException
            ? _messageFromError(e)
            : e.toString().replaceFirst('Exception: ', ''),
      );
      return;
    }
    final refreshed = await _ref.read(clinovaApiProvider).me();
    final verifiedUser = AppUser.fromJson(refreshed);
    state = state.copyWith(
      stage: AuthStage.signedIn,
      token: token,
      user: verifiedUser,
      isBusy: false,
      clearPendingEmail: true,
      clearPendingRegisterNames: true,
      clearPendingPasswordForOtp: true,
      clearOtpIntent: true,
      clearDebugCode: true,
      clearError: true,
    );
    authDebugLog('auth state signedIn');
  }

  Future<void> passwordLogin({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final response = await _ref.read(clinovaApiProvider).passwordLogin(
            email: email,
            password: password,
          );
      await _applySuccessfulPasswordLoginResponse(response);
    } on DioException catch (error) {
      final data = error.response?.data;
      if (error.response?.statusCode == 403 &&
          data is Map &&
          data['error']?.toString() == 'EMAIL_NOT_VERIFIED') {
        final canonicalEmail =
            data['email']?.toString().trim().toLowerCase() ??
                email.trim().toLowerCase();
        state = state.copyWith(
          stage: AuthStage.codeSent,
          pendingEmail: canonicalEmail,
          otpIntent: OtpIntent.emailVerification,
          clearPendingPasswordForOtp: true,
          isBusy: false,
          clearError: true,
        );
        return;
      }
      state = state.copyWith(
        isBusy: false,
        errorMessage: _messageFromError(error),
      );
    }
  }

  Future<void> googleSignIn({required String idToken}) async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final response =
          await _ref.read(clinovaApiProvider).googleAuth(idToken: idToken);
      final token = response['accessToken']?.toString() ?? '';
      if (token.isEmpty) {
        state = state.copyWith(
          isBusy: false,
          errorMessage:
              'Google нэвтрэлт амжилтгүй боллоо. Серверээс token ирээгүй байна.',
        );
        return;
      }
      await _persistTokensFromResponse(response);
      final user = AppUser.fromJson(
        response['user'] is Map<String, dynamic>
            ? response['user'] as Map<String, dynamic>
            : <String, dynamic>{},
      );
      try {
        await _verifyAccountWithBackend(user);
      } catch (e) {
        await _ref.read(tokenStorageProvider).clearAll();
        state = state.copyWith(
          stage: AuthStage.signedOut,
          isBusy: false,
          clearToken: true,
          clearUser: true,
          errorMessage: e is DioException
              ? _googleBackendMessage(e)
              : _googleVerifyFailureMessage(e),
        );
        return;
      }
      final refreshed = await _ref.read(clinovaApiProvider).me();
      final verifiedUser = AppUser.fromJson(refreshed);
      state = state.copyWith(
        stage: AuthStage.signedIn,
        token: token,
        user: verifiedUser,
        isBusy: false,
        clearPendingEmail: true,
        clearPendingRegisterNames: true,
        clearPendingPasswordForOtp: true,
        clearOtpIntent: true,
        clearDebugCode: true,
        clearError: true,
      );
    } on DioException catch (error) {
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.connectionError) {
        state = state.copyWith(
          isBusy: false,
          errorMessage:
              'Сервертэй холбогдож чадсангүй. Интернет эсвэл API хаягаа шалгана уу.',
        );
        return;
      }
      state = state.copyWith(
        isBusy: false,
        errorMessage: _googleBackendMessage(error),
      );
    } catch (error) {
      state = state.copyWith(
        isBusy: false,
        errorMessage: _unexpectedGoogleSignInError(error),
      );
    }
  }

  /// Ensures token works and role-specific dashboard is reachable before sign-in.
  Future<void> _verifyAccountWithBackend(AppUser user) async {
    final role = user.role;
    if (role == 'PATIENT') {
      if (user.patientProfileId == null || user.patientProfileId!.isEmpty) {
        throw Exception(
          'Patient profile is missing. Complete registration or contact clinic.',
        );
      }
      await _ref.read(clinovaApiProvider).getPatientDashboard();
      return;
    }
    if (role == 'DOCTOR') {
      if (user.doctorProfileId == null || user.doctorProfileId!.isEmpty) {
        throw Exception(
          'Doctor profile is missing. Contact administrator.',
        );
      }
      await _ref.read(clinovaApiProvider).getDoctorDashboard();
      return;
    }
    if (role == 'ADMIN' || role == 'STAFF') {
      await _ref.read(clinovaApiProvider).getAdminDashboard();
    }
  }

  Future<void> registerWithPassword({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phoneNumber,
  }) async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final response =
          await _ref.read(clinovaApiProvider).registerPatient(
                email: email,
                password: password,
                firstName: firstName,
                lastName: lastName,
                phoneNumber: phoneNumber,
              );
      final token = response['accessToken']?.toString() ?? '';
      if (token.isNotEmpty) {
        await _persistTokensFromResponse(response);
        final user = AppUser.fromJson(
          response['user'] is Map<String, dynamic>
              ? response['user'] as Map<String, dynamic>
              : <String, dynamic>{},
        );
        try {
          await _verifyAccountWithBackend(user);
        } catch (e) {
          await _ref.read(tokenStorageProvider).clearAll();
          state = state.copyWith(
            stage: AuthStage.signedOut,
            isBusy: false,
            clearToken: true,
            clearUser: true,
            errorMessage: e is DioException
                ? _messageFromError(e)
                : e.toString().replaceFirst('Exception: ', ''),
          );
          return;
        }
        final refreshed = await _ref.read(clinovaApiProvider).me();
        final verifiedUser = AppUser.fromJson(refreshed);
        state = state.copyWith(
          stage: AuthStage.signedIn,
          token: token,
          user: verifiedUser,
          isBusy: false,
          clearPendingEmail: true,
          clearPendingRegisterNames: true,
          clearOtpIntent: true,
          clearDebugCode: true,
          clearError: true,
        );
        return;
      }
      final devCode = response['debugCode']?.toString();
      state = state.copyWith(
        stage: AuthStage.codeSent,
        pendingEmail: email,
        pendingFirstName: firstName,
        pendingLastName: lastName,
        otpIntent: OtpIntent.register,
        clearDebugCode: devCode == null,
        debugCode: devCode,
        isBusy: false,
        clearError: true,
      );
    } on DioException catch (error) {
      state = state.copyWith(
        isBusy: false,
        errorMessage: _messageFromError(error),
      );
    }
  }

  Future<void> requestForgotPassword({required String email}) async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final response =
          await _ref.read(clinovaApiProvider).forgotPassword(email: email);
      state = state.copyWith(
        stage: AuthStage.codeSent,
        pendingEmail: email,
        otpIntent: OtpIntent.forgotPassword,
        debugCode: response['debugCode']?.toString(),
        isBusy: false,
        clearError: true,
      );
    } on DioException catch (error) {
      state = state.copyWith(
        isBusy: false,
        errorMessage: _forgotPasswordErrorMessage(error),
      );
    }
  }

  Future<void> requestOtp({
    required String email,
    String? firstName,
    String? lastName,
    OtpIntent otpIntent = OtpIntent.signInCode,
  }) async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final response = await _ref
          .read(clinovaApiProvider)
          .requestOtp(email: email, firstName: firstName, lastName: lastName);
      state = state.copyWith(
        stage: AuthStage.codeSent,
        pendingEmail: email,
        pendingFirstName: firstName,
        pendingLastName: lastName,
        otpIntent: otpIntent,
        debugCode: response['debugCode']?.toString(),
        isBusy: false,
        clearError: true,
      );
    } on DioException catch (error) {
      state = state.copyWith(
        isBusy: false,
        errorMessage: _messageFromError(error),
      );
    }
  }

  Future<void> resendOtpCode() async {
    final email = state.pendingEmail;
    if (email == null || email.isEmpty) return;

    switch (state.otpIntent) {
      case OtpIntent.forgotPassword:
        await requestForgotPassword(email: email);
        return;
      case OtpIntent.register:
      case OtpIntent.emailVerification:
        await _resendVerificationEmail(email);
        return;
      case OtpIntent.signInCode:
        await requestOtp(
          email: email,
          firstName: state.pendingFirstName,
          lastName: state.pendingLastName,
          otpIntent: OtpIntent.signInCode,
        );
        return;
      case null:
        await requestOtp(
          email: email,
          firstName: state.pendingFirstName,
          lastName: state.pendingLastName,
        );
    }
  }

  Future<void> _resendVerificationEmail(String email) async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await _ref.read(clinovaApiProvider).resendVerification(email: email);
      state = state.copyWith(isBusy: false, clearError: true);
    } on DioException catch (error) {
      state = state.copyWith(
        isBusy: false,
        errorMessage: _messageFromError(error),
      );
    }
  }

  Future<void> resetPasswordWithOtp({
    required String otp,
    required String newPassword,
  }) async {
    final email = state.pendingEmail;
    if (email == null || email.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Email address is missing. Start over from forgot password.',
      );
      return;
    }
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await _ref.read(clinovaApiProvider).resetPassword(
            email: email,
            otp: otp,
            newPassword: newPassword,
          );
      state = state.copyWith(
        stage: AuthStage.signedOut,
        isBusy: false,
        clearPendingEmail: true,
        clearOtpIntent: true,
        clearDebugCode: true,
        clearError: true,
      );
    } on DioException catch (error) {
      state = state.copyWith(
        isBusy: false,
        errorMessage: _messageFromError(error),
      );
    }
  }

  Future<void> verifyOtp(String otp) async {
    final email = state.pendingEmail;
    if (email == null || email.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Email address is missing. Request a new code first.',
      );
      return;
    }

    state = state.copyWith(isBusy: true, clearError: true);

    try {
      final Map<String, dynamic> response;
      switch (state.otpIntent) {
        case OtpIntent.register:
        case OtpIntent.emailVerification:
          response = await _ref.read(clinovaApiProvider).verifyEmail(
                email: email,
                code: otp,
              );
          break;
        case OtpIntent.signInCode:
          response = await _ref.read(clinovaApiProvider).verifyOtp(
                email: email,
                otp: otp,
                purpose: _otpPurposeForVerify(),
              );
          break;
        case OtpIntent.forgotPassword:
        case null:
          throw StateError('Invalid OTP intent for verifyOtp.');
      }
      final token = response['accessToken']?.toString() ?? '';
      if (token.isEmpty) {
        state = state.copyWith(
          isBusy: false,
          errorMessage: 'Verification response did not include a token. Try again.',
        );
        return;
      }
      await _persistTokensFromResponse(response);
      final user = AppUser.fromJson(
        response['user'] is Map<String, dynamic>
            ? response['user'] as Map<String, dynamic>
            : <String, dynamic>{},
      );
      try {
        await _verifyAccountWithBackend(user);
      } catch (e) {
        await _ref.read(tokenStorageProvider).clearAll();
        state = state.copyWith(
          stage: AuthStage.signedOut,
          isBusy: false,
          clearToken: true,
          clearUser: true,
          clearPendingPasswordForOtp: true,
          errorMessage: e is DioException
              ? _messageFromError(e)
              : e.toString().replaceFirst('Exception: ', ''),
        );
        return;
      }
      final refreshed = await _ref.read(clinovaApiProvider).me();
      final verifiedUser = AppUser.fromJson(refreshed);
      state = state.copyWith(
        stage: AuthStage.signedIn,
        token: token,
        user: verifiedUser,
        isBusy: false,
        clearPendingEmail: true,
        clearPendingRegisterNames: true,
        clearPendingPasswordForOtp: true,
        clearOtpIntent: true,
        clearDebugCode: true,
        clearError: true,
      );
    } on StateError catch (e) {
      state = state.copyWith(
        isBusy: false,
        errorMessage: e.message,
      );
    } on DioException catch (error) {
      state = state.copyWith(
        isBusy: false,
        errorMessage: _messageFromError(error),
      );
    }
  }

  /// Refetches `/auth/me` into [AuthState.user] (profile photo, nickname, etc.).
  Future<void> reloadCurrentUser() async {
    if (state.stage != AuthStage.signedIn) return;
    try {
      final map = await _ref.read(clinovaApiProvider).me();
      state = state.copyWith(
        user: AppUser.fromJson(map),
        clearError: true,
      );
    } catch (_) {}
  }

  Future<void> logout() async {
    final storage = _ref.read(tokenStorageProvider);
    final refresh = await storage.readRefreshToken();
    try {
      await _ref.read(clinovaApiProvider).logout(refreshToken: refresh);
    } catch (_) {}
    await storage.clearAll();
    state = state.copyWith(
      stage: AuthStage.signedOut,
      isBusy: false,
      clearToken: true,
      clearUser: true,
      clearPendingEmail: true,
      clearPendingRegisterNames: true,
      clearPendingPasswordForOtp: true,
      clearOtpIntent: true,
      clearDebugCode: true,
      clearError: true,
    );
  }

  Future<void> refreshCurrentUser() async {
    if (state.token == null) return;
    try {
      final userJson = await _ref.read(clinovaApiProvider).me();
      state = state.copyWith(
        user: AppUser.fromJson(userJson),
        stage: AuthStage.signedIn,
      );
    } catch (_) {}
  }

  Future<void> handleUnauthorized() async {
    if (state.stage == AuthStage.signedOut) return;
    authDebugLog('handleUnauthorized — clearing session');
    await logout();
  }

  void dismissError() {
    state = state.copyWith(clearError: true);
  }

  /// Friendly copy for [forgotPassword] / forgot-flow resend; keeps English backend text out of the UI.
  String _forgotPasswordErrorMessage(DioException error) {
    final status = error.response?.statusCode;
    if (status == 429) {
      return _lookupL10n().authForgotRateLimitMessage;
    }
    final data = error.response?.data;
    if (data is Map && data['message'] != null) {
      final msg = data['message'].toString().toLowerCase();
      if (msg.contains('please wait before requesting') ||
          msg.contains('too many requests') ||
          msg.contains('rate limit')) {
        return _lookupL10n().authForgotRateLimitMessage;
      }
    }
    return _messageFromError(error);
  }

  String _messageFromError(DioException error) {
    final path = error.requestOptions.path;
    final status = error.response?.statusCode;
    if (status == 401 && path.contains('/auth/password-login')) {
      return 'Имэйл эсвэл нууц үг буруу байна.';
    }
    final data = error.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return error.message ?? 'Something went wrong.';
  }

  String _googleBackendMessage(DioException error) {
    final base = _messageFromError(error);
    if (base.contains('Google sign-in is not configured')) {
      return 'Google нэвтрэлт сервер дээр тохируулагдаагүй байна. (GOOGLE_CLIENT_ID эсвэл GOOGLE_CLIENT_IDS заавал.)';
    }
    if (base.contains('Invalid Google token')) {
      return 'Google баталгаажуулалт амжилтгүй. Вэб Client ID болон Google Cloud Console дээрх Authorized JavaScript origins-ийг (clinova.uk, www.clinova.uk) шалгана уу.';
    }
    if (base.contains('Google account has no email')) {
      return 'Google бүртгэлд имэйл байхгүй байна.';
    }
    if (base.contains('not active')) {
      return 'Энэ бүртгэл идэвхгүй байна. Админтай холбогдоно уу.';
    }
    return base;
  }

  String _googleVerifyFailureMessage(Object error) {
    final s = error.toString().replaceFirst('Exception: ', '');
    if (s.contains('Patient profile is missing')) {
      return 'Өвчтөний профайл олдсонгүй. Дахин оролдоно уу эсвэл эмнэлэгт хандана уу.';
    }
    if (s.contains('Doctor profile is missing')) {
      return 'Эмчийн профайл олдсонгүй. Админтай холбогдоно уу.';
    }
    return _unexpectedGoogleSignInError(error);
  }

  String _unexpectedGoogleSignInError(Object error) {
    final raw = error.toString();
    if (raw.contains('Null check operator used on a null value')) {
      return 'Google нэвтрэлт тохиргоо дутуу байна. Дахин deploy хийж шалгана уу.';
    }
    return 'Google нэвтрэлт амжилтгүй боллоо.';
  }
}
