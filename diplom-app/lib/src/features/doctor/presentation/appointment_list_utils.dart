/// Merges [updated] from PATCH /appointments/:id/status into an existing list item.
List<Map<String, dynamic>> patchAppointmentInList(
  List<Map<String, dynamic>> list,
  String appointmentId,
  Map<String, dynamic> updated,
  String fallbackStatus,
) {
  return list.map((item) {
    if (item['id']?.toString() != appointmentId) return item;
    return mergeAppointmentMaps(item, updated, fallbackStatus);
  }).toList();
}

Map<String, dynamic> mergeAppointmentMaps(
  Map<String, dynamic> existing,
  Map<String, dynamic> updated,
  String fallbackStatus,
) {
  return {
    ...existing,
    ...updated,
    'status': (updated['status'] ?? fallbackStatus).toString(),
    if (updated['patient'] != null) 'patient': updated['patient'],
    if (updated['doctor'] != null) 'doctor': updated['doctor'],
    if (updated['service'] != null) 'service': updated['service'],
    if (updated['branch'] != null) 'branch': updated['branch'],
  };
}

/// Applies [updated] to both dashboard appointment lists (today + upcoming).
/// Completed/cancelled appointments are removed to match backend filters.
Map<String, dynamic> patchDoctorDashboardAppointments(
  Map<String, dynamic> dashboard,
  String appointmentId,
  Map<String, dynamic> updated,
  String fallbackStatus,
) {
  final newStatus =
      (updated['status'] ?? fallbackStatus).toString().toUpperCase();
  final removeFromLists =
      newStatus == 'COMPLETED' || newStatus == 'CANCELLED';

  List<Map<String, dynamic>> patchList(dynamic raw) {
    final items =
        (raw as List?)?.cast<Map<String, dynamic>>() ?? const <Map<String, dynamic>>[];
    if (removeFromLists) {
      return items
          .where((item) => item['id']?.toString() != appointmentId)
          .toList();
    }
    return patchAppointmentInList(items, appointmentId, updated, fallbackStatus);
  }

  return {
    ...dashboard,
    'todayAppointments': patchList(dashboard['todayAppointments']),
    'upcomingAppointments': patchList(dashboard['upcomingAppointments']),
  };
}
