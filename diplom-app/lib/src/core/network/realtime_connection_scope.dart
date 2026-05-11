import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../../features/auth/application/auth_controller.dart';
import '../notifications/clinova_realtime_toast.dart';
import '../notifications/realtime_notification_bridge.dart';
import 'doctor_chat_dm_room.dart';
import 'online_presence_provider.dart';
import 'pending_inbound_call_provider.dart';
import 'realtime_service.dart';

/// Нэвтэрсэн эмч / өвчтөнд realtime WebSocket автоматаар холбож, төвийн бус экранээс ч
/// дуудлагыг барьж үлдээхэд түр хүлээлтээр дамжуулна.
class RealtimeConnectionScope extends ConsumerStatefulWidget {
  const RealtimeConnectionScope({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<RealtimeConnectionScope> createState() =>
      _RealtimeConnectionScopeState();
}

class _RealtimeConnectionScopeState
    extends ConsumerState<RealtimeConnectionScope> {
  StreamSubscription<Map<String, dynamic>>? _offerNavSub;
  StreamSubscription<Map<String, dynamic>>? _chatToastSub;
  StreamSubscription<Map<String, dynamic>>? _presenceSub;
  StreamSubscription<Map<String, dynamic>>? _apptBookSub;
  StreamSubscription<Map<String, dynamic>>? _apptUpdatedSub;
  StreamSubscription<Map<String, dynamic>>? _chatRequestSub;
  StreamSubscription<Map<String, dynamic>>? _chatRequestResolvedSub;

  @override
  void initState() {
    super.initState();
    _syncAuth(ref.read(authControllerProvider));
    final rt = ref.read(realtimeServiceProvider);
    _offerNavSub = rt.callSignalStream.listen(
      _navigateInboundOfferIfAwayFromChat,
    );
    _chatToastSub = rt.chatMessageStream.listen(_onChatMessageToast);
    _presenceSub = rt.presenceStream.listen(_onPresence);
    _apptBookSub = rt.appointmentBookedStream.listen(_onAppointmentBooked);
    _apptUpdatedSub = rt.appointmentUpdatedStream.listen(
      _onAppointmentUpdated,
    );
    _chatRequestSub = rt.chatRequestStream.listen(_onChatRequest);
    _chatRequestResolvedSub =
        rt.chatRequestResolvedStream.listen(_onChatRequestResolved);
  }

  void _onChatMessageToast(Map<String, dynamic> data) {
    handleGlobalChatMessageToast(
      ref,
      data,
      ref.read(appRouterProvider),
    );
  }

  void _onPresence(Map<String, dynamic> data) {
    final uid = data['userId']?.toString() ?? '';
    final st = data['status']?.toString() ?? '';
    ref
        .read(onlineUserIdsProvider.notifier)
        .applyPresence(userId: uid, status: st);
  }

  void _onAppointmentBooked(dynamic raw) {
    if (raw is! Map) return;
    unawaited(
      handleAppointmentRealtimeToast(
        ref,
        Map<String, dynamic>.from(raw),
        'booked',
      ),
    );
  }

  void _onAppointmentUpdated(dynamic raw) {
    if (raw is! Map) return;
    unawaited(
      handleAppointmentRealtimeToast(
        ref,
        Map<String, dynamic>.from(raw),
        'updated',
      ),
    );
  }

  void _onChatRequest(Map<String, dynamic> data) {
    handleChatRequestIncomingToast(ref, data);
  }

  void _onChatRequestResolved(Map<String, dynamic> data) {
    handleChatRequestResolvedToast(ref, data);
  }

  void _syncAuth(AuthState auth) {
    final uid = auth.user?.id.trim();
    final token = auth.token?.trim() ?? '';
    if (auth.isAuthenticated && uid != null && uid.isNotEmpty) {
      ref.read(realtimeServiceProvider).connect(userId: uid, accessToken: token);
    } else {
      ref.read(realtimeServiceProvider).disconnect();
    }
  }

  void _navigateInboundOfferIfAwayFromChat(Map<String, dynamic> raw) {
    final event = raw['event']?.toString() ?? '';
    if (event != 'call:offer') return;

    final toUid = raw['toUserId']?.toString().trim() ?? '';
    final authUser = ref.read(authControllerProvider).user;
    final myId = authUser?.id.trim() ?? '';
    if (toUid.isEmpty || myId.isEmpty || toUid != myId) return;

    final router = ref.read(appRouterProvider);
    final path = router.state.uri.path;
    final onDoctorChatRoute =
        path == '/doctor-chat' || path.startsWith('/doctor-chat/');
    if (onDoctorChatRoute) return;

    final roomId = raw['roomId']?.toString() ?? '';
    final parsed = parseDoctorChatDmRoom(roomId);
    if (parsed == null) return;

    ref.read(pendingInboundCallSignalProvider.notifier).state =
        Map<String, dynamic>.from(raw);

    final role = authUser?.role ?? 'PATIENT';
    if (role == 'DOCTOR') {
      final docId = authUser?.doctorProfileId?.trim() ?? '';
      if (docId.isEmpty || parsed.doctorProfileId != docId) {
        ref.read(pendingInboundCallSignalProvider.notifier).state = null;
        return;
      }
      router.go('/doctor-chat');
      return;
    }

    if (parsed.patientUserId != myId) {
      ref.read(pendingInboundCallSignalProvider.notifier).state = null;
      return;
    }
    router.go(
      Uri(
        path: '/doctor-chat',
        queryParameters: {
          'conversationId': roomId,
          'doctorId': parsed.doctorProfileId,
        },
      ).toString(),
    );
  }

  @override
  void dispose() {
    _offerNavSub?.cancel();
    _chatToastSub?.cancel();
    _presenceSub?.cancel();
    _apptBookSub?.cancel();
    _apptUpdatedSub?.cancel();
    _chatRequestSub?.cancel();
    _chatRequestResolvedSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(
      authControllerProvider,
      (prev, next) => _syncAuth(next),
    );
    return ClinovaRealtimeToastLayer(child: widget.child);
  }
}
