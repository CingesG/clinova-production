import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:web/web.dart' as web;

import '../../features/auth/application/auth_controller.dart';
import 'clinova_realtime_toast.dart';

bool clinovaTabVisible() {
  if (kIsWeb) {
    try {
      return web.document.visibilityState == 'visible';
    } catch (_) {
      return true;
    }
  }
  return true;
}

/// Maps realtime payloads into lightweight toasts (+ optional haptic).
void handleGlobalChatMessageToast(
  WidgetRef ref,
  Map<String, dynamic> data,
  GoRouter router,
) {
  final auth = ref.read(authControllerProvider);
  final myId = auth.user?.id.trim() ?? '';
  if (!auth.isAuthenticated || myId.isEmpty) return;
  final sender = data['senderId']?.toString() ?? '';
  if (sender.isEmpty || sender == myId) return;
  final receiver = data['receiverId']?.toString() ?? '';
  if (receiver.isNotEmpty && receiver != myId) return;
  final path = router.state.uri.path;
  if (path == '/doctor-chat' || path.startsWith('/doctor-chat/')) return;

  final text = data['text']?.toString().trim() ?? '';
  final preview = text.isEmpty
      ? (data['messageType']?.toString() == 'IMAGE'
            ? 'Зураг илгээлээ'
            : 'Шинэ мессеж')
      : (text.length > 96 ? '${text.substring(0, 93)}…' : text);

  final title = ref.read(authControllerProvider).user?.role == 'DOCTOR'
      ? 'Өвчтөн'
      : 'Эмч';

  if (clinovaTabVisible()) {
    unawaited(clinovaPlaySoftRealtimeCue());
  }
  ref.read(clinovaRealtimeToastsProvider.notifier).push(
        ClinovaToast(
          id: 'chat-${data['id'] ?? DateTime.now().millisecondsSinceEpoch}',
          title: title,
          body: preview,
        ),
      );
}

Future<void> handleAppointmentRealtimeToast(
  WidgetRef ref,
  Map<String, dynamic> appt,
  String kind,
) async {
  final auth = ref.read(authControllerProvider);
  final myId = auth.user?.id.trim() ?? '';
  if (!auth.isAuthenticated || myId.isEmpty) return;

  final patientUser = appt['patient'];
  Map<String, dynamic>? pu;
  if (patientUser is Map<String, dynamic>) {
    pu = patientUser;
  } else if (patientUser is Map) {
    pu = Map<String, dynamic>.from(patientUser);
  }
  final patientNestedUser = pu?['user'];
  Map<String, dynamic>? pun;
  if (patientNestedUser is Map<String, dynamic>) {
    pun = patientNestedUser;
  } else if (patientNestedUser is Map) {
    pun = Map<String, dynamic>.from(patientNestedUser);
  }
  final patientUid = pun?['id']?.toString() ?? '';

  final doctor = appt['doctor'];
  Map<String, dynamic>? dmap;
  if (doctor is Map<String, dynamic>) {
    dmap = doctor;
  } else if (doctor is Map) {
    dmap = Map<String, dynamic>.from(doctor);
  }
  final du = dmap?['user'];
  Map<String, dynamic>? duu;
  if (du is Map<String, dynamic>) {
    duu = du;
  } else if (du is Map) {
    duu = Map<String, dynamic>.from(du);
  }
  final doctorUid = duu?['id']?.toString() ?? '';

  if (patientUid != myId && doctorUid != myId) return;

  final serviceName =
      (appt['service'] is Map ? (appt['service'] as Map)['name'] : null)
          ?.toString() ??
      '';
  final status = appt['status']?.toString() ?? '';

  final dname = duu == null
      ? 'Эмч'
      : '${duu['firstName'] ?? ''} ${duu['lastName'] ?? ''}'.trim();

  final title = kind == 'booked' ? 'Цаг баталгаажлаа' : 'Цагийн шинэчлэлт';
  final body = serviceName.isNotEmpty
      ? '$dname · $serviceName · $status'
      : '$dname · $status';

  if (clinovaTabVisible()) {
    await clinovaPlaySoftRealtimeCue();
  }
  ref.read(clinovaRealtimeToastsProvider.notifier).push(
        ClinovaToast(
          id: 'appt-${'${appt['id']}-$kind'.hashCode}',
          title: title,
          body: body,
        ),
      );
}

void handleChatRequestIncomingToast(WidgetRef ref, Map<String, dynamic> data) {
  final auth = ref.read(authControllerProvider);
  if (auth.user?.role != 'DOCTOR' || !auth.isAuthenticated) return;
  final name = data['patientName']?.toString().trim();
  final body = name != null && name.isNotEmpty
      ? '$name чат хүсэлт илгээлээ'
      : 'Шинэ чат хүсэлт ирлээ';
  if (clinovaTabVisible()) {
    unawaited(clinovaPlaySoftRealtimeCue());
  }
  ref.read(clinovaRealtimeToastsProvider.notifier).push(
        ClinovaToast(
          id: 'chat-req-${data['requestId'] ?? DateTime.now().millisecondsSinceEpoch}',
          title: 'Чат хүсэлт',
          body: body,
        ),
      );
}

void handleChatRequestResolvedToast(
  WidgetRef ref,
  Map<String, dynamic> data,
) {
  final auth = ref.read(authControllerProvider);
  if (auth.user?.role != 'PATIENT' || !auth.isAuthenticated) return;
  final outcome = data['outcome']?.toString() ?? '';
  if (outcome != 'ACCEPTED') return;
  final doctorName = data['doctorName']?.toString().trim();
  final body = doctorName != null && doctorName.isNotEmpty
      ? '$doctorName таны хүсэлтийг зөвшөөрлөө'
      : 'Эмч чат хүсэлтийг зөвшөөрлөө';
  if (clinovaTabVisible()) {
    unawaited(clinovaPlaySoftRealtimeCue());
  }
  ref.read(clinovaRealtimeToastsProvider.notifier).push(
        ClinovaToast(
          id: 'chat-acc-${data['requestId'] ?? DateTime.now().millisecondsSinceEpoch}',
          title: 'Чат нээгдлээ',
          body: body,
        ),
      );
}
