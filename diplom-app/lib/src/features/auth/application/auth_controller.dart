import 'package:dio/dio.dart';
import 'package:diplom_app/l10n/app_localizations.dart';
import 'package:diplom_app/l10n/app_localizations_en.dart';
import 'package:diplom_app/l10n/app_localizations_mn.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/clinova_api.dart';
import '../../../core/network/token_refresh.dart';
import '../../../core/storage/token_storage.dart';
import '../../settings/presentation/language_controller.dart';
import '../domain/app_user.dart';

enum AuthStage { bootstrapping, signedOut, codeSent, signedIn }

enum OtpIntent {
  signInCode,
  register,
  forgotPassword,
  emailPasswordSecondFactor,
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
  });

  final AuthStage stage;
  final AppUser? user;
  final String? token;
  final String? pendingEmail;
  final String? pendingFirstName;
  final String? pendingLastName;
  /// Short-lived: password step for resending login OTP. Cleared after verify/logout.
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
    );
  }

  factory AuthState.initial() {
    return const AuthState(stage: AuthStage.bootstrapping);
  }
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

  Future<void> bootstrap() async {
    if (_bootstrapped) return;
    _bootstrapped = true;

    final storage = _ref.read(tokenStorageProvider);
    final token = await storage.readToken();
    if (token == null || token.isEmpty) {
      state = state.copyWith(
        stage: AuthStage.signedOut,
        clearToken: true,
        clearUser: true,
        clearPendingEmail: true,
        clearPendingRegisterNames: true,
        clearPendingPasswordForOtp: true,
        clearOtpIntent: true,
        clearDebugCode: true,
        clearError: true,
      );
      return;
    }

    state = state.copyWith(token: token, isBusy: true, clearError: true);

    try {
      final userJson = await _ref.read(clinovaApiProvider).me();
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
    } catch (_) {
      final rotated = await refreshClinovaTokensCoordinated(storage);
      if (rotated) {
        final newAccess = await storage.readToken() ?? '';
        if (newAccess.isNotEmpty) {
          state = state.copyWith(token: newAccess);
          try {
            final userJson = await _ref.read(clinovaApiProvider).me();
            state = state.copyWith(
              stage: AuthStage.signedIn,
              token: newAccess,
              user: AppUser.fromJson(userJson),
              isBusy: false,
              clearPendingEmail: true,
              clearPendingRegisterNames: true,
              clearPendingPasswordForOtp: true,
              clearOtpIntent: true,
              clearDebugCode: true,
              clearError: true,
            );
            return;
          } catch (_) {}
        }
      }
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
  }

  /// Keeps in-memory [AuthState.token] aligned with secure storage after a silent refresh.
  void applyRefreshedAccessToken(String accessToken) {
    if (accessToken.isEmpty) return;
    if (state.stage != AuthStage.signedIn || state.user == null) return;
    state = state.copyWith(token: accessToken);
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
    if (access.isEmpty) return;
    await storage.saveToken(access);
    if (refresh.isNotEmpty) {
      await storage.saveRefreshToken(refresh);
    }
  }

  /// Maps [AuthState.otpIntent] to the backend `purpose` for `POST /auth/verify-otp`.
  ///
  /// Email/password login with OTP second factor uses [OtpIntent.emailPasswordSecondFactor]
  /// and the same `LOGIN` purpose as passwordless email OTP ([OtpIntent.signInCode]).
  String _otpPurposeForVerify() {
    switch (state.otpIntent) {
      case OtpIntent.register:
        return 'REGISTER';
      case OtpIntent.signInCode:
        return 'LOGIN';
      case OtpIntent.emailPasswordSecondFactor:
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

  /// Finishes sign-in after [passwordLogin] / [resendLoginOtp] returned tokens (no OTP step).
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
      if (response['requiresEmailVerification'] == true) {
        final canonicalEmail =
            response['email']?.toString().trim().toLowerCase() ??
                email.trim().toLowerCase();
        if (canonicalEmail.endsWith('@clinova.local')) {
          state = state.copyWith(
            isBusy: false,
            errorMessage: _lookupL10n().authClinovaLocalUsePasswordOnly,
          );
          return;
        }
        final devCode = response['debugCode']?.toString();
        state = state.copyWith(
          stage: AuthStage.codeSent,
          pendingEmail: canonicalEmail,
          otpIntent: OtpIntent.emailPasswordSecondFactor,
          pendingPasswordForOtp: password,
          clearDebugCode: devCode == null,
          debugCode: devCode,
          isBusy: false,
          clearError: true,
        );
        return;
      }
      await _applySuccessfulPasswordLoginResponse(response);
    } on DioException catch (error) {
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
      case OtpIntent.emailPasswordSecondFactor:
        final password = state.pendingPasswordForOtp;
        if (password == null || password.isEmpty) return;
        state = state.copyWith(isBusy: true, clearError: true);
        try {
          final response = await _ref.read(clinovaApiProvider).resendLoginOtp(
                email: email,
                password: password,
              );
          if (response['requiresEmailVerification'] == true) {
            final canonical = response['email']?.toString().trim().toLowerCase() ??
                email.trim().toLowerCase();
            if (canonical.endsWith('@clinova.local')) {
              state = state.copyWith(
                isBusy: false,
                errorMessage: _lookupL10n().authClinovaLocalUsePasswordOnly,
              );
              return;
            }
            final devCode = response['debugCode']?.toString();
            state = state.copyWith(
              isBusy: false,
              clearDebugCode: devCode == null,
              debugCode: devCode,
              clearError: true,
            );
            return;
          }
          await _applySuccessfulPasswordLoginResponse(response);
        } on DioException catch (error) {
          state = state.copyWith(
            isBusy: false,
            errorMessage: _messageFromError(error),
          );
        }
        return;
      case OtpIntent.register:
        await requestOtp(
          email: email,
          firstName: state.pendingFirstName,
          lastName: state.pendingLastName,
          otpIntent: OtpIntent.register,
        );
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
      final purpose = _otpPurposeForVerify();
      final response = await _ref.read(clinovaApiProvider).verifyOtp(
            email: email,
            otp: otp,
            purpose: purpose,
          );
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

  void handleUnauthorized() {
    if (state.stage == AuthStage.signedOut) return;
    logout();
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
      return 'Google нэвтрэлт сервер дээр тохируулагдаагүй байна.';
    }
    if (base.contains('Invalid Google token')) {
      return 'Google баталгаажуулалт амжилтгүй. Client ID таарах эсэхийг шалгана уу.';
    }
    if (base.contains('Google account has no email')) {
      return 'Google бүртгэлд имэйл байхгүй байна.';
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
