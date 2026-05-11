/// Location for `/doctor-chat` after [ClinovaApi.startDoctorConversation].
///
/// [res.doctorId] / [res.doctor.id] = **DoctorProfile.id** (not User.id).
/// [res.doctor.userId] = doctor's **User.id** (socket receiver).
/// [res.id] = persisted DM room id (`room-{patientUserId}-doc-{doctorProfileId}`).
String doctorChatDetailLocationFromStartResponse(Map<String, dynamic> res) {
  final d = res['doctor'];
  final dm = d is Map<String, dynamic> ? d : <String, dynamic>{};
  final room = (res['id'] ?? '').toString().trim();
  final doctorProfileId =
      (res['doctorId'] ?? dm['id'] ?? '').toString().trim();
  if (room.isEmpty || doctorProfileId.isEmpty) {
    throw FormatException(
      'startDoctorConversation: missing id (room) or doctorId in response',
    );
  }
  var doctorName = (dm['name'] ?? '').toString().trim();
  if (doctorName.isEmpty) {
    doctorName = doctorProfileId;
  }
  return Uri(
    path: '/doctor-chat',
    queryParameters: <String, String>{
      'conversationId': room,
      'doctorId': doctorProfileId,
      'doctorName': doctorName,
      if (dm['avatarUrl'] != null && '${dm['avatarUrl']}'.trim().isNotEmpty)
        'doctorAvatar': '${dm['avatarUrl']}'.trim(),
      if (dm['userId'] != null && '${dm['userId']}'.trim().isNotEmpty)
        'doctorUserId': '${dm['userId']}'.trim(),
    },
  ).toString();
}
