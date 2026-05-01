import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../../features/auth/application/auth_controller.dart';
import 'doctor_chat_dm_room.dart';
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

  @override
  void initState() {
    super.initState();
    _syncAuth(ref.read(authControllerProvider));
    _offerNavSub = ref.read(realtimeServiceProvider).callSignalStream.listen(
          _navigateInboundOfferIfAwayFromChat,
        );
  }

  void _syncAuth(AuthState auth) {
    final uid = auth.user?.id.trim();
    if (auth.isAuthenticated && uid != null && uid.isNotEmpty) {
      ref.read(realtimeServiceProvider).connect(userId: uid);
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
      '/doctor-chat?doctorId=${Uri.encodeComponent(parsed.doctorProfileId)}',
    );
  }

  @override
  void dispose() {
    _offerNavSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(
      authControllerProvider,
      (prev, next) => _syncAuth(next),
    );
    return widget.child;
  }
}
