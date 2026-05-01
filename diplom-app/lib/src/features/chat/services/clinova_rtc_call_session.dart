import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../core/network/realtime_service.dart';
import 'clinova_ringtone.dart';

enum ChatCallOverlayPhase { idle, outgoing, incoming, active, ending }

typedef ClinovaRtcPhaseCallback = void Function();

/// WebRTC peer + ringtone UX for clinician–patient socket signaling.
class ClinovaRtcCallSession {
  ClinovaRtcCallSession({
    required this.realtime,
    required this.selfUserId,
    required this.peerUserId,
    required this.roomId,
    required this.onPhaseChanged,
  });

  final RealtimeService realtime;
  final String selfUserId;
  final String peerUserId;
  final String roomId;
  final ClinovaRtcPhaseCallback onPhaseChanged;

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  ChatCallOverlayPhase phase = ChatCallOverlayPhase.idle;

  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  RTCSessionDescription? _pendingOffer;
  bool _incomingVideo = false;
  bool _callerUsesVideo = false;

  bool _renderersReady = false;

  bool get expectsVideoTiles =>
      phase != ChatCallOverlayPhase.idle &&
      phase != ChatCallOverlayPhase.ending &&
      (_callerUsesVideo || _incomingVideo);

  static const Map<String, dynamic> _ice = {
    'sdpSemantics': 'unified-plan',
    'iceServers': [
      {
        'urls': ['stun:stun.l.google.com:19302'],
      },
    ],
  };

  Future<void> ensureRenderers() async {
    if (_renderersReady) return;
    await localRenderer.initialize();
    await remoteRenderer.initialize();
    _renderersReady = true;
  }

  Future<void> disposeSession() async {
    await hangup(skipSocket: true);
    try {
      await localRenderer.dispose();
      await remoteRenderer.dispose();
    } catch (_) {}
  }

  Future<void> hangup({bool skipSocket = false}) async {
    await stopClinovaCallRingtone();
    try {
      await _localStream?.dispose();
    } catch (_) {}
    _localStream = null;
    try {
      await _pc?.close();
      await _pc?.dispose();
    } catch (_) {}
    _pc = null;
    _pendingOffer = null;
    _callerUsesVideo = false;
    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;
    if (!skipSocket && phase != ChatCallOverlayPhase.idle) {
      realtime.endCall(roomId, selfUserId,
          reason: 'user-ended', peerUserId: peerUserId);
    }
    phase = ChatCallOverlayPhase.idle;
    onPhaseChanged();
  }

  static RTCSessionDescription? sdpFrom(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final body = (m['sdp'] ?? '').toString();
    final ty = (m['type'] ?? '').toString();
    if (body.isEmpty || ty.isEmpty) return null;
    return RTCSessionDescription(body, ty);
  }

  Future<void> startOutbound({required bool video}) async {
    if (_pc != null) return;
    await ensureRenderers();
    await stopClinovaCallRingtone();
    realtime.joinCall(roomId, selfUserId, callType: video ? 'video' : 'voice');
    _callerUsesVideo = video;
    phase = ChatCallOverlayPhase.outgoing;
    await startClinovaCallRingtone();
    onPhaseChanged();

    final p = await _createPc();

    try {
      await _attachLocalMicCam(p, video: video);

      final offer = await p.createOffer();
      await p.setLocalDescription(offer);

      final om = offer.toMap();
      final payload = Map<String, dynamic>.from(om as Map);
      payload['webrtc'] = true;
      payload['callKind'] = video ? 'video' : 'audio';
      realtime.sendCallOffer(roomId, selfUserId, peerUserId, payload);
    } catch (e) {
      debugPrint('WebRTC outbound error: $e');
      await hangup(skipSocket: true);
    }
  }

  Future<void> onInboundOffer(
    Map<String, dynamic> rawEvent, {
    required bool isForMe,
  }) async {
    if (!isForMe) return;
    final nested = rawEvent['sdp'];
    final desc = sdpFrom(nested);
    if (desc == null || desc.type != 'offer') return;

    if (_pc != null || phase == ChatCallOverlayPhase.outgoing) {
      await hangup(skipSocket: true);
    }

    await ensureRenderers();
    _pendingOffer = desc;
    _incomingVideo = rawEvent['callKind']?.toString() == 'video' ||
        (nested is Map && nested['callKind']?.toString() == 'video');
    phase = ChatCallOverlayPhase.incoming;
    await startClinovaCallRingtone();
    onPhaseChanged();
  }

  Future<void> acceptIncoming() async {
    if (_pendingOffer == null || _pc != null) return;

    phase = ChatCallOverlayPhase.active;
    await stopClinovaCallRingtone();
    onPhaseChanged();

    realtime.joinCall(roomId, selfUserId, callType: _incomingVideo ? 'video' : 'voice');

    final p = await _createPc();
    try {
      await p.setRemoteDescription(_pendingOffer!);
      _pendingOffer = null;

      await _attachLocalMicCam(p, video: _incomingVideo);

      final answer = await p.createAnswer({});
      await p.setLocalDescription(answer);

      final am = answer.toMap();
      final payload = Map<String, dynamic>.from(am as Map);
      payload['webrtc'] = true;
      payload['callKind'] = _incomingVideo ? 'video' : 'audio';
      realtime.sendCallAnswer(roomId, selfUserId, peerUserId, payload);
      onPhaseChanged();
    } catch (e) {
      debugPrint('WebRTC answer error: $e');
      await hangup(skipSocket: true);
    }
  }

  void rejectIncoming() {
    stopClinovaCallRingtone();
    _pendingOffer = null;
    realtime.endCall(roomId, selfUserId,
        reason: 'rejected', peerUserId: peerUserId);
    phase = ChatCallOverlayPhase.idle;
    onPhaseChanged();
  }

  Future<void> handleRemoteAnswer(dynamic sdpRaw) async {
    final desc = sdpFrom(sdpRaw);
    if (desc == null || _pc == null || desc.type != 'answer') return;
    await stopClinovaCallRingtone();
    try {
      await _pc!.setRemoteDescription(desc);
      phase = ChatCallOverlayPhase.active;
      onPhaseChanged();
    } catch (e) {
      debugPrint('setRemote(answer) failed: $e');
    }
  }

  Future<void> addRemoteIceCandidate(dynamic raw) async {
    if (_pc == null || raw is! Map) return;
    final m = Map<String, dynamic>.from(raw);
    final cand = m['candidate']?.toString();
    if (cand == null || cand.isEmpty) return;

    try {
      final mid = m['sdpMid']?.toString();
      final idx = _asInt(m['sdpMLineIndex']);
      await _pc!.addCandidate(
        RTCIceCandidate(cand, mid, idx),
      );
    } catch (e) {
      debugPrint('addIce: $e');
    }
  }

  Future<RTCPeerConnection> _createPc() async {
    final p = await createPeerConnection(
      Map<String, dynamic>.from(_ice),
      {
        'mandatory': {},
        'optional': [],
      },
    );

    _pc = p;

    p.onTrack = (evt) {
      if (evt.streams.isEmpty) return;
      remoteRenderer.srcObject = evt.streams.first;
      onPhaseChanged();
    };

    p.onIceCandidate = (candidate) async {
      final c = candidate.candidate;
      if (c == null || c.isEmpty) return;
      final raw = candidate.toMap();
      realtime.sendIceCandidate(
        roomId,
        selfUserId,
        Map<String, dynamic>.from(raw as Map),
        toUserId: peerUserId,
      );
    };

    return p;
  }

  Future<void> _attachLocalMicCam(
    RTCPeerConnection p, {
    required bool video,
  }) async {
    await _localStream?.dispose();
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': video
          ? {
              'facingMode': 'user',
              'width': {'ideal': 1280},
              'height': {'ideal': 720},
            }
          : false,
    });
    localRenderer.srcObject = _localStream;
    for (final track in _localStream!.getTracks()) {
      await p.addTrack(track, _localStream!);
    }
    onPhaseChanged();
  }

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }
}
