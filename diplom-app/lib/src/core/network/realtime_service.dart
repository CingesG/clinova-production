import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/app_config.dart';

final realtimeServiceProvider = Provider<RealtimeService>((ref) {
  final service = RealtimeService();
  ref.onDispose(service.dispose);
  return service;
});

class RealtimeService {
  io.Socket? _socket;
  String _currentAccessToken = '';
  final StreamController<Map<String, dynamic>> _chatStream =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _typingStream =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _callSignalStream =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _presenceStream =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _appointmentBookedStream =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _appointmentUpdatedStream =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _chatRequestStream =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _chatRequestResolvedStream =
      StreamController<Map<String, dynamic>>.broadcast();

  /// One broadcast stream for all `chat:message` events; filter by `roomId` in the listener.
  Stream<Map<String, dynamic>> get chatMessageStream => _chatStream.stream;
  Stream<Map<String, dynamic>> get typingStream => _typingStream.stream;
  Stream<Map<String, dynamic>> get callSignalStream => _callSignalStream.stream;
  Stream<Map<String, dynamic>> get presenceStream => _presenceStream.stream;
  Stream<Map<String, dynamic>> get appointmentBookedStream =>
      _appointmentBookedStream.stream;
  Stream<Map<String, dynamic>> get appointmentUpdatedStream =>
      _appointmentUpdatedStream.stream;
  Stream<Map<String, dynamic>> get chatRequestStream =>
      _chatRequestStream.stream;
  Stream<Map<String, dynamic>> get chatRequestResolvedStream =>
      _chatRequestResolvedStream.stream;

  void connect({String? userId, String? accessToken}) {
    final normalizedUserId = (userId ?? '').trim();
    final normalizedAccessToken = (accessToken ?? '').trim();
    if (_socket != null) {
      final existingQuery = _socket!.io.options?['query'];
      final existingUserId = existingQuery is Map
          ? (existingQuery['userId']?.toString() ?? '').trim()
          : '';
      if (existingUserId != normalizedUserId ||
          _currentAccessToken != normalizedAccessToken) {
        _socket!.dispose();
        _socket = null;
      }
    }

    _currentAccessToken = normalizedAccessToken;
    try {
      _socket ??= io.io(
        '${AppConfig.realtimeBaseUrl}/realtime',
        io.OptionBuilder()
            .setTransports(['polling', 'websocket'])
            .setQuery({'userId': normalizedUserId})
            .setAuth({'token': normalizedAccessToken, 'userId': normalizedUserId})
            .setReconnectionAttempts(5)
            .setReconnectionDelay(1500)
            .disableAutoConnect()
            .build(),
      );
    } catch (e, st) {
      developer.log(
        'Realtime socket init failed (fallback to non-realtime mode)',
        name: 'RealtimeService',
        error: e,
        stackTrace: st,
      );
      _socket = null;
      return;
    }
    _socket!
      ..off('chat:message')
      ..off('chat:typing')
      ..off('call:offer')
      ..off('call:answer')
      ..off('call:ice')
      ..off('call:end')
      ..off('presence:changed')
      ..off('appointments:booked')
      ..off('appointments:updated')
      ..off('chat:request')
      ..off('chat:request:resolved')
      ..off('connect')
      ..off('connect_error')
      ..off('disconnect')
      ..off('error')
      ..on('connect', (_) {
        developer.log(
          'Realtime connected: ${_socket?.id ?? 'unknown'}',
          name: 'RealtimeService',
        );
      })
      ..on('connect_error', (error) {
        developer.log(
          'Realtime connect error',
          name: 'RealtimeService',
          error: error,
        );
      })
      ..on('disconnect', (reason) {
        developer.log(
          'Realtime disconnected: ${reason ?? 'unknown'}',
          name: 'RealtimeService',
        );
      })
      ..on('error', (error) {
        developer.log(
          'Realtime socket error',
          name: 'RealtimeService',
          error: error,
        );
      })
      ..on('chat:message', (data) {
        final map = _asMap(data);
        if (map != null) _chatStream.add(map);
      })
      ..on('chat:typing', (data) {
        final map = _asMap(data);
        if (map != null) _typingStream.add(map);
      })
      ..on('presence:changed', (data) {
        final map = _asMap(data);
        if (map != null) _presenceStream.add(map);
      })
      ..on('appointments:booked', (data) {
        final map = _asMap(data);
        if (map != null) _appointmentBookedStream.add(map);
      })
      ..on('appointments:updated', (data) {
        final map = _asMap(data);
        if (map != null) _appointmentUpdatedStream.add(map);
      })
      ..on('chat:request', (data) {
        final map = _asMap(data);
        if (map != null) _chatRequestStream.add(map);
      })
      ..on('chat:request:resolved', (data) {
        final map = _asMap(data);
        if (map != null) _chatRequestResolvedStream.add(map);
      })
      ..on('call:offer', (data) {
        final map = _asMap(data);
        if (map != null) _callSignalStream.add({'event': 'call:offer', ...map});
      })
      ..on('call:answer', (data) {
        final map = _asMap(data);
        if (map != null) _callSignalStream.add({'event': 'call:answer', ...map});
      })
      ..on('call:ice', (data) {
        final map = _asMap(data);
        if (map != null) _callSignalStream.add({'event': 'call:ice', ...map});
      })
      ..on('call:end', (data) {
        final map = _asMap(data);
        if (map != null) _callSignalStream.add({'event': 'call:end', ...map});
      });
    try {
      _socket!.connect();
    } catch (e, st) {
      developer.log(
        'Realtime connect invoke failed',
        name: 'RealtimeService',
        error: e,
        stackTrace: st,
      );
    }
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
    _currentAccessToken = '';
  }

  void joinRoom(String roomId) {
    _socket?.emit('chat:join', {'roomId': roomId});
  }

  void sendMessage(
    String roomId,
    String senderId,
    String text, {
    String? receiverId,
    String messageType = 'TEXT',
    String? attachmentUrl,
    String? attachmentName,
    String? attachmentMime,
    int? attachmentSize,
    Map<String, dynamic>? metadata,
  }) {
    _socket?.emit('chat:message', {
      'roomId': roomId,
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'messageType': messageType,
      'attachmentUrl': attachmentUrl,
      'attachmentName': attachmentName,
      'attachmentMime': attachmentMime,
      'attachmentSize': attachmentSize,
      'metadata': metadata,
    });
  }

  void sendTyping(String roomId, String userId, bool isTyping) {
    _socket?.emit('chat:typing', {
      'roomId': roomId,
      'userId': userId,
      'isTyping': isTyping,
    });
  }

  void joinCall(String roomId, String userId, {String callType = 'voice'}) {
    _socket?.emit('call:join', {
      'roomId': roomId,
      'userId': userId,
      'callType': callType,
    });
  }

  void sendCallOffer(String roomId, String fromUserId, String toUserId, Map<String, dynamic> sdp) {
    _socket?.emit('call:offer', {
      'roomId': roomId,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'sdp': sdp,
    });
  }

  void sendCallAnswer(String roomId, String fromUserId, String toUserId, Map<String, dynamic> sdp) {
    _socket?.emit('call:answer', {
      'roomId': roomId,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'sdp': sdp,
    });
  }

  void sendIceCandidate(
    String roomId,
    String fromUserId,
    Map<String, dynamic> candidate, {
    required String toUserId,
  }) {
    _socket?.emit('call:ice', {
      'roomId': roomId,
      'fromUserId': fromUserId,
      'candidate': candidate,
      'toUserId': toUserId,
    });
  }

  void endCall(
    String roomId,
    String userId, {
    String? reason,
    String? peerUserId,
  }) {
    _socket?.emit('call:end', {
      'roomId': roomId,
      'userId': userId,
      'reason': reason,
      if (peerUserId != null && peerUserId.isNotEmpty) 'peerUserId': peerUserId,
    });
  }

  void dispose() {
    _socket?.dispose();
    _socket = null;
    _currentAccessToken = '';
    _chatStream.close();
    _typingStream.close();
    _callSignalStream.close();
    _presenceStream.close();
    _appointmentBookedStream.close();
    _appointmentUpdatedStream.close();
    _chatRequestStream.close();
    _chatRequestResolvedStream.close();
  }

  Map<String, dynamic>? _asMap(dynamic data) {
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    if (data == null) return null;
    developer.log(
      'Realtime event payload is not a map: ${data.runtimeType}',
      name: 'RealtimeService',
    );
    return null;
  }
}
