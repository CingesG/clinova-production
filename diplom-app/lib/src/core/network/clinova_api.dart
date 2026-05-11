import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../media/clinova_avatar_url.dart';
import 'api_client.dart';

final clinovaApiProvider = Provider<ClinovaApi>((ref) {
  return ClinovaApi(ref.watch(apiClientProvider));
});

class ClinovaApi {
  ClinovaApi(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> requestOtp({
    required String email,
    String? firstName,
    String? lastName,
  }) async {
    final payload = <String, dynamic>{'email': email};
    if (firstName != null) payload['firstName'] = firstName;
    if (lastName != null) payload['lastName'] = lastName;

    final response = await _dio.post('/auth/request-otp', data: payload);
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> verifyEmail({
    required String email,
    required String code,
  }) async {
    final response = await _dio.post(
      '/auth/verify-email',
      data: {'email': email, 'code': code},
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> resendVerification({
    required String email,
  }) async {
    final response = await _dio.post(
      '/auth/resend-verification',
      data: {'email': email},
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String email,
    required String otp,
    required String purpose,
  }) async {
    final response = await _dio.post(
      '/auth/verify-otp',
      data: {'email': email, 'otp': otp, 'purpose': purpose},
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> resendLoginOtp({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post(
      '/auth/resend-login-otp',
      data: {'email': email, 'password': password},
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> googleAuth({required String idToken}) async {
    final response = await _dio.post(
      '/auth/google',
      data: {'idToken': idToken},
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> refreshTokens({
    required String refreshToken,
  }) async {
    final response = await _dio.post(
      '/auth/refresh',
      data: {'refreshToken': refreshToken},
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    final response = await _dio.post(
      '/auth/reset-password',
      data: {'email': email, 'otp': otp, 'newPassword': newPassword},
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> passwordLogin({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post(
      '/auth/password-login',
      data: {'email': email, 'password': password},
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> registerPatient({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phoneNumber,
  }) async {
    final response = await _dio.post(
      '/auth/register',
      data: {
        'email': email,
        'password': password,
        'firstName': firstName,
        'lastName': lastName,
        'phoneNumber': phoneNumber,
      },
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> forgotPassword({required String email}) async {
    final response = await _dio.post(
      '/auth/forgot-password',
      data: {'email': email},
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> me() async {
    final response = await _dio.get('/auth/me');
    final map = _asMap(response.data);
    return _normalizeUserJson(map);
  }

  /// PATCH `/users/me` — nickname, avatar URL, etc.
  Future<Map<String, dynamic>> patchMyProfile(
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.patch('/users/me', data: payload);
    final map = _asMap(response.data);
    return _normalizeUserJson(map);
  }

  /// PATCH `/users/me/password` — имэйл/нууц үгээр нэвтэрсэн хэрэглэгчид.
  Future<void> changeMyPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _dio.patch(
      '/users/me/password',
      data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
  }

  Map<String, dynamic> _normalizeUserJson(Map<String, dynamic> raw) {
    final a = _absolutizeUrl(raw['avatarUrl']?.toString());
    if (a != null) {
      raw['avatarUrl'] = a;
    }
    final pn = raw['phoneNumber']?.toString().trim();
    final legacy = raw['phone']?.toString().trim();
    if ((pn == null || pn.isEmpty) && legacy != null && legacy.isNotEmpty) {
      raw['phoneNumber'] = legacy;
    }
    return raw;
  }

  Future<void> logout({String? refreshToken}) async {
    await _dio.post(
      '/auth/logout',
      data: refreshToken != null ? {'refreshToken': refreshToken} : {},
    );
  }

  /// Persisted doctor–patient chat history (room id must match the socket room).
  Future<List<Map<String, dynamic>>> getChatMessages(String roomId) async {
    final encoded = Uri.encodeComponent(roomId);
    final response = await _dio.get('/chat/$encoded/messages');
    if (response.data is! List) {
      return const [];
    }
    return _asList(response.data);
  }

  /// Doctors the patient may DM (appointment or accepted chat request).
  Future<List<Map<String, dynamic>>> getPatientAllowedChatDoctors() async {
    final response = await _dio.get('/chat/patient-allowed-doctors');
    return _normalizeTopLevelList(response.data);
  }

  /// POST `/chat/conversations/start` — [doctorId] must be **DoctorProfile.id**, not User.id.
  Future<Map<String, dynamic>> startDoctorConversation({
    required String doctorId,
  }) async {
    final response = await _dio.post(
      '/chat/conversations/start',
      data: {'doctorId': doctorId},
    );
    return _asMap(response.data);
  }

  Future<Map<String, Map<String, dynamic>>> getChatPermissionFlags({
    required List<String> doctorIds,
  }) async {
    final response = await _dio.post(
      '/chat/permission-flags',
      data: {'doctorIds': doctorIds},
    );
    final raw = response.data;
    if (raw is! Map) return {};
    return raw.map(
      (k, v) => MapEntry(
        k.toString(),
        v is Map
            ? Map<String, dynamic>.from(v)
            : <String, dynamic>{},
      ),
    );
  }

  Future<Map<String, dynamic>> createDoctorChatRequest({
    required String doctorProfileId,
    String? note,
  }) async {
    final response = await _dio.post(
      '/chat/requests',
      data: {
        'doctorProfileId': doctorProfileId,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
    return _asMap(response.data);
  }

  Future<List<Map<String, dynamic>>> getDoctorChatRequestsIncoming() async {
    final response = await _dio.get('/chat/requests/incoming');
    return _normalizeTopLevelList(response.data);
  }

  Future<Map<String, dynamic>> acceptDoctorChatRequest(String requestId) async {
    final response = await _dio.patch('/chat/requests/$requestId/accept');
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> declineDoctorChatRequest(String requestId) async {
    final response = await _dio.patch('/chat/requests/$requestId/decline');
    return _asMap(response.data);
  }

  /// GET bytes from an absolute or API-relative upload/chart URL.
  Future<Uint8List> downloadAttachmentBytes(String absoluteOrRelativeUrl) async {
    final u =
        _absolutizeUrl(absoluteOrRelativeUrl) ?? absoluteOrRelativeUrl.trim();
    if (u.isEmpty) {
      throw DioException(
        requestOptions: RequestOptions(path: u),
        message: 'Bad URL',
      );
    }
    final response = await _dio.get<List<int>>(
      u,
      options: Options(
        responseType: ResponseType.bytes,
        validateStatus: (s) => s != null && s >= 200 && s < 400,
      ),
    );
    final data = response.data ?? const <int>[];
    if (data.isEmpty) {
      throw DioException(
        requestOptions: response.requestOptions,
        message: 'Empty download',
      );
    }
    return Uint8List.fromList(data);
  }

  Future<Map<String, dynamic>> uploadChatAttachment({
    required Uint8List bytes,
    required String filename,
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final response = await _dio.post(
      '/chat/upload',
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );
    final out = _asMap(response.data);
    final absoluteUrl = _absolutizeUrl(out['url']?.toString());
    final absoluteRelative = _absolutizeUrl(out['relativeUrl']?.toString());
    if (absoluteUrl != null) out['url'] = absoluteUrl;
    if ((out['url']?.toString().isEmpty ?? true) && absoluteRelative != null) {
      out['url'] = absoluteRelative;
    }
    if (absoluteRelative != null) out['relativeUrl'] = absoluteRelative;
    return out;
  }

  Future<List<Map<String, dynamic>>> getBranches() async {
    final response = await _dio.get('/branches');
    return _normalizeTopLevelList(response.data);
  }

  Future<List<Map<String, dynamic>>> getDepartments() async {
    final response = await _dio.get('/departments');
    return _normalizeTopLevelList(response.data);
  }

  Future<List<Map<String, dynamic>>> getServices({
    String? branchId,
    String? departmentId,
    String? doctorId,
    int page = 1,
    int pageSize = 100,
  }) async {
    final queryParameters = <String, dynamic>{
      'page': page,
      'pageSize': pageSize,
    };
    if (branchId != null) queryParameters['branchId'] = branchId;
    if (departmentId != null) queryParameters['departmentId'] = departmentId;
    if (doctorId != null) queryParameters['doctorId'] = doctorId;

    final response = await _dio.get(
      '/services',
      queryParameters: queryParameters,
    );
    return _asList(_asMap(response.data)['items']);
  }

  Future<List<Map<String, dynamic>>> getDoctors({
    String? branchId,
    String? departmentId,
    String? serviceId,
  }) async {
    final queryParameters = <String, dynamic>{};
    if (branchId != null) queryParameters['branchId'] = branchId;
    if (departmentId != null) queryParameters['departmentId'] = departmentId;
    if (serviceId != null) queryParameters['serviceId'] = serviceId;

    final response = await _dio.get(
      '/doctors',
      queryParameters: queryParameters,
    );
    // Match other list endpoints: raw array or `{ items | data | results: [...] }`.
    final list = _normalizeTopLevelList(response.data);
    return list.map(_withAbsoluteDoctorAvatar).toList();
  }

  /// Public doctor profile (`DoctorProfile.id`).
  Future<Map<String, dynamic>> getDoctor(String doctorProfileId) async {
    final response = await _dio.get('/doctors/$doctorProfileId');
    return _withAbsoluteDoctorAvatar(_asMap(response.data));
  }

  Future<List<Map<String, dynamic>>> getDoctorPatients() async {
    final response = await _dio.get('/doctors/me/patients');
    return _asList(response.data).map(_withAbsoluteDoctorAvatar).toList();
  }

  Future<List<Map<String, dynamic>>> getAvailableSlots({
    required String date,
    String? branchId,
    String? departmentId,
    String? serviceId,
    String? doctorId,
  }) async {
    final queryParameters = <String, dynamic>{'date': date};
    if (branchId != null) queryParameters['branchId'] = branchId;
    if (departmentId != null) queryParameters['departmentId'] = departmentId;
    if (serviceId != null) queryParameters['serviceId'] = serviceId;
    if (doctorId != null) queryParameters['doctorId'] = doctorId;

    final response = await _dio.get(
      '/appointments/slots',
      queryParameters: queryParameters,
    );
    return _asList(response.data);
  }

  Future<List<Map<String, dynamic>>> getRecommendedSlots({
    required String date,
    String? branchId,
    String? departmentId,
    String? serviceId,
    String? doctorId,
    int? preferredStartHour,
    int? preferredEndHour,
    int limit = 5,
  }) async {
    final queryParameters = <String, dynamic>{'date': date, 'limit': limit};
    if (branchId != null) queryParameters['branchId'] = branchId;
    if (departmentId != null) queryParameters['departmentId'] = departmentId;
    if (serviceId != null) queryParameters['serviceId'] = serviceId;
    if (doctorId != null) queryParameters['doctorId'] = doctorId;
    if (preferredStartHour != null) {
      queryParameters['preferredStartHour'] = preferredStartHour;
    }
    if (preferredEndHour != null) {
      queryParameters['preferredEndHour'] = preferredEndHour;
    }

    final response = await _dio.get(
      '/appointments/recommend',
      queryParameters: queryParameters,
    );
    return _asList(response.data);
  }

  Future<List<Map<String, dynamic>>> getLoadBalancedDoctors({
    required String serviceId,
    String? branchId,
    String? departmentId,
    int limit = 5,
  }) async {
    final queryParameters = <String, dynamic>{
      'serviceId': serviceId,
      'limit': limit,
    };
    if (branchId != null) queryParameters['branchId'] = branchId;
    if (departmentId != null) queryParameters['departmentId'] = departmentId;
    final response = await _dio.get(
      '/doctors/suggestions/load-balance',
      queryParameters: queryParameters,
    );
    return _asList(response.data);
  }

  Future<Map<String, dynamic>> getServiceIntakeSchema(String serviceId) async {
    final response = await _dio.get('/services/$serviceId/intake-schema');
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> acquireSlotLock({
    required String doctorId,
    required String serviceId,
    required String startsAt,
  }) async {
    final response = await _dio.post(
      '/appointments/slot-lock',
      data: {
        'doctorId': doctorId,
        'serviceId': serviceId,
        'startsAt': startsAt,
      },
    );
    return _asMap(response.data);
  }

  Future<void> releaseSlotLock(String lockId) async {
    await _dio.patch('/appointments/slot-lock/$lockId/release');
  }

  Future<Map<String, dynamic>> createAppointment({
    required String doctorId,
    required String serviceId,
    required String startsAt,
    String? reason,
    String? slotLockId,
    Map<String, dynamic>? intakeAnswers,
    bool withPaymentIntent = false,
  }) async {
    final payload = <String, dynamic>{
      'doctorId': doctorId,
      'serviceId': serviceId,
      'startsAt': startsAt,
    };
    if (reason != null) payload['reason'] = reason;
    if (slotLockId != null) payload['slotLockId'] = slotLockId;
    if (intakeAnswers != null && intakeAnswers.isNotEmpty) {
      payload['intakeAnswers'] = intakeAnswers;
    }
    payload['withPaymentIntent'] = withPaymentIntent;

    final response = await _dio.post('/appointments', data: payload);
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> joinAppointmentWaitlist({
    required String serviceId,
    String? branchId,
    String? departmentId,
    String? preferredDate,
    int? preferredHourStart,
    int? preferredHourEnd,
    String? note,
  }) async {
    final payload = <String, dynamic>{'serviceId': serviceId};
    if (branchId != null) payload['branchId'] = branchId;
    if (departmentId != null) payload['departmentId'] = departmentId;
    if (preferredDate != null) payload['preferredDate'] = preferredDate;
    if (preferredHourStart != null) {
      payload['preferredHourStart'] = preferredHourStart;
    }
    if (preferredHourEnd != null) {
      payload['preferredHourEnd'] = preferredHourEnd;
    }
    if (note != null && note.isNotEmpty) payload['note'] = note;
    final response = await _dio.post('/appointments/waitlist', data: payload);
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> createPaymentIntent({
    required int amount,
    required String appointmentId,
  }) async {
    final response = await _dio.post(
      '/payments/intent',
      data: {'amount': amount, 'appointmentId': appointmentId},
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> triageAgent({
    required String symptoms,
    String? age,
    String? gender,
    String? duration,
    String? severity,
  }) async {
    final payload = <String, dynamic>{'symptoms': symptoms};
    if (age != null && age.isNotEmpty) payload['age'] = age;
    if (gender != null && gender.isNotEmpty) payload['gender'] = gender;
    if (duration != null && duration.isNotEmpty) payload['duration'] = duration;
    if (severity != null && severity.isNotEmpty) {
      payload['severity'] = severity;
    }

    final response = await _dio.post('/api/ai/triage', data: payload);
    return _asMap(response.data);
  }

  /// Multi-purpose Clinova AI agent (triage, Q&A, app help, routing).
  /// [message] may be empty when [images] is non-empty.
  Future<Map<String, dynamic>> agentChat({
    String message = '',
    List<Map<String, dynamic>>? images,
    String? conversationId,
    String? userId,
    Map<String, dynamic>? context,
  }) async {
    final payload = <String, dynamic>{'message': message};
    if (images != null && images.isNotEmpty) {
      payload['images'] = images;
    }
    if (conversationId != null && conversationId.isNotEmpty) {
      payload['conversationId'] = conversationId;
    }
    if (userId != null && userId.isNotEmpty) {
      payload['userId'] = userId;
    }
    if (context != null && context.isNotEmpty) {
      payload['context'] = context;
    }
    try {
      final response = await _dio.post('/api/ai/chat', data: payload);
      return _asMap(response.data);
    } on DioException catch (_) {
      final response = await _dio.post('/api/ai/agent', data: payload);
      return _asMap(response.data);
    }
  }

  Future<Map<String, dynamic>> agentRecommend({
    required String message,
    Map<String, dynamic>? context,
  }) async {
    final payload = <String, dynamic>{'message': message};
    if (context != null && context.isNotEmpty) {
      payload['context'] = context;
    }
    final response = await _dio.post('/api/ai/recommend', data: payload);
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> agentActions({
    required String message,
    Map<String, dynamic>? context,
  }) async {
    final payload = <String, dynamic>{'message': message};
    if (context != null && context.isNotEmpty) {
      payload['context'] = context;
    }
    final response = await _dio.post('/api/ai/actions', data: payload);
    return _asMap(response.data);
  }

  /// Legacy: single text field (maps to [triageAgent]).
  Future<Map<String, dynamic>> triageSymptoms(String symptomText) async {
    return triageAgent(symptoms: symptomText);
  }

  Future<Map<String, dynamic>> getAppointments({String? status}) async {
    final queryParameters = <String, dynamic>{};
    if (status != null) queryParameters['status'] = status;

    final response = await _dio.get(
      '/appointments',
      queryParameters: queryParameters,
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> updateAppointmentStatus({
    required String appointmentId,
    required String status,
    String? cancellationReason,
  }) async {
    final payload = <String, dynamic>{'status': status};
    if (cancellationReason != null) {
      payload['cancellationReason'] = cancellationReason;
    }

    final response = await _dio.patch(
      '/appointments/$appointmentId/status',
      data: payload,
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> getPatientDashboard() async {
    final response = await _dio.get('/dashboard/patient');
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> getDoctorDashboard() async {
    final response = await _dio.get('/dashboard/doctor');
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> getAdminDashboard() async {
    final response = await _dio.get('/dashboard/admin');
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> getUsers() async {
    final response = await _dio.get('/users');
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> updateUser({
    required String userId,
    String? status,
    String? role,
    String? password,
  }) async {
    final payload = <String, dynamic>{};
    if (status != null) payload['status'] = status;
    if (role != null) payload['role'] = role;
    if (password != null && password.trim().isNotEmpty) {
      payload['password'] = password.trim();
    }

    final response = await _dio.patch('/users/$userId', data: payload);
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> getJobApplications() async {
    final response = await _dio.get('/jobs/applications');
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> updateJobApplication({
    required String applicationId,
    String? status,
    String? internalNote,
  }) async {
    final payload = <String, dynamic>{};
    if (status != null) payload['status'] = status;
    if (internalNote != null) payload['internalNote'] = internalNote;

    final response = await _dio.patch(
      '/jobs/applications/$applicationId',
      data: payload,
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> createBranch(
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post('/branches', data: payload);
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> createService(
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post('/services', data: payload);
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> createDoctor(
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post('/doctors', data: payload);
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> submitDoctorFeedback({
    required String doctorProfileId,
    required int stars,
    required int carePoints,
    String? comment,
    String? appointmentId,
  }) async {
    final payload = <String, dynamic>{'stars': stars, 'carePoints': carePoints};
    if (comment != null && comment.trim().isNotEmpty) {
      payload['comment'] = comment.trim();
    }
    if (appointmentId != null && appointmentId.trim().isNotEmpty) {
      payload['appointmentId'] = appointmentId.trim();
    }
    final response = await _dio.post(
      '/doctors/$doctorProfileId/feedback',
      data: payload,
    );
    return _asMap(response.data);
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    return {};
  }

  List<Map<String, dynamic>> _asList(dynamic data) {
    if (data is! List) {
      return const [];
    }
    return data
        .map((item) => _asMap(item))
        .where((item) => item.isNotEmpty)
        .toList();
  }

  /// Branches/departments may be a raw JSON array or wrapped (`items`, `data`).
  List<Map<String, dynamic>> _normalizeTopLevelList(dynamic data) {
    if (data is List) {
      return _asList(data);
    }
    if (data is Map) {
      final map = _asMap(data);
      final nested = map['items'] ?? map['data'] ?? map['results'];
      if (nested is List) {
        return _asList(nested);
      }
    }
    return const [];
  }

  Map<String, dynamic> _withAbsoluteDoctorAvatar(Map<String, dynamic> doctor) {
    final out = Map<String, dynamic>.from(doctor);
    final userRaw = out['user'];
    if (userRaw is Map) {
      final user = _asMap(userRaw);
      final avatar = _absolutizeUrl(user['avatarUrl']?.toString());
      if (avatar != null) {
        user['avatarUrl'] = avatar;
      }
      out['user'] = user;
    }
    final avatarTop = _absolutizeUrl(out['avatarUrl']?.toString());
    if (avatarTop != null) {
      out['avatarUrl'] = avatarTop;
    }
    return out;
  }

  String? _absolutizeUrl(String? raw) => clinovaAbsolutizeMediaUrl(raw);
}
