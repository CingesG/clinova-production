/// `room-{patientUserId}-doc-{doctorProfileId}` форматийн чатын өрөөний ID парслагч.
class DoctorChatDmRoom {
  const DoctorChatDmRoom({
    required this.patientUserId,
    required this.doctorProfileId,
  });

  final String patientUserId;
  final String doctorProfileId;

  @override
  String toString() =>
      'DoctorChatDmRoom(patient:$patientUserId doc:$doctorProfileId)';
}

DoctorChatDmRoom? parseDoctorChatDmRoom(String roomId) {
  const prefix = 'room-';
  const mid = '-doc-';
  if (!roomId.startsWith(prefix) || !roomId.contains(mid)) return null;
  final rest = roomId.substring(prefix.length);
  final idx = rest.lastIndexOf(mid);
  if (idx < 0) return null;
  final patientUserId = rest.substring(0, idx).trim();
  final doctorProfileId = rest.substring(idx + mid.length).trim();
  if (patientUserId.isEmpty || doctorProfileId.isEmpty) return null;
  return DoctorChatDmRoom(
    patientUserId: patientUserId,
    doctorProfileId: doctorProfileId,
  );
}
