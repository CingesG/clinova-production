import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/clinova_api.dart';

final doctorChatStartServiceProvider = Provider<DoctorChatStartService>((ref) {
  return DoctorChatStartService(ref.watch(clinovaApiProvider));
});

/// Starts (or reuses) the patient–doctor DM conversation on the backend.
class DoctorChatStartService {
  DoctorChatStartService(this._api);

  final ClinovaApi _api;

  Future<Map<String, dynamic>> startDoctorChat(String doctorProfileId) {
    return _api.startDoctorConversation(doctorId: doctorProfileId);
  }

  /// Maps HTTP failures from [startDoctorChat] to short MN user copy.
  static String userMessageForStartFailure(Object error) {
    if (error is DioException) {
      final code = error.response?.statusCode;
      final path = error.requestOptions.path;
      if (kDebugMode && code == 404) {
        debugPrint(
          '[Clinova][DoctorChatStart] endpoint not found (404): $path',
        );
      }
      if (code == 403) {
        return 'Энэ эмчтэй чатлах эрх одоогоор нээгдээгүй байна.';
      }
      if (code == 404) {
        return 'Чат үйлчилгээний холбоос олдсонгүй.';
      }
      if (code != null && code >= 500) {
        return 'Чат эхлүүлэхэд алдаа гарлаа. Дахин оролдоно уу.';
      }
    }
    return 'Чат эхлүүлэхэд алдаа гарлаа. Дахин оролдоно уу.';
  }
}
