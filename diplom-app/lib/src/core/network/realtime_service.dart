import 'dart:async';

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

  void connect({String? userId}) {
    final normalizedUserId = (userId ?? '').trim();
    if (_socket != null) {
      final existingQuery = _socket!.io.options?['query'];
      final existingUserId = existingQuery is Map
          ? (existingQuery['userId']?.toString() ?? '').trim()
          : '';
      if (existingUserId != normalizedUserId) {
        _socket!.dispose();
        _socket = null;
      }
    }

    _socket ??= io.io(
      '${AppConfig.realtimeBaseUrl}/realtime',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setQuery({'userId': normalizedUserId})
          .setAuth({'userId': normalizedUserId})
          .disableAutoConnect()
          .build(),
    );
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
      ..on('chat:message', (data) {
        _chatStream.add(Map<String, dynamic>.from(data as Map));
      })
      ..on('chat:typing', (data) {
        _typingStream.add(Map<String, dynamic>.from(data as Map));
      })
      ..on('presence:changed', (data) {
        _presenceStream.add(Map<String, dynamic>.from(data as Map));
      })
      ..on('appointments:booked', (data) {
        _appointmentBookedStream.add(Map<String, dynamic>.from(data as Map));
      })
      ..on('appointments:updated', (data) {
        _appointmentUpdatedStream.add(Map<String, dynamic>.from(data as Map));
      })
      ..on('chat:request', (data) {
        _chatRequestStream.add(Map<String, dynamic>.from(data as Map));
      })
      ..on('chat:request:resolved', (data) {
        _chatRequestResolvedStream.add(Map<String, dynamic>.from(data as Map));
      })
      ..on('call:offer', (data) {
        _callSignalStream.add({'event': 'call:offer', ...Map<String, dynamic>.from(data as Map)});
      })
      ..on('call:answer', (data) {
        _callSignalStream.add({'event': 'call:answer', ...Map<String, dynamic>.from(data as Map)});
      })
      ..on('call:ice', (data) {
        _callSignalStream.add({'event': 'call:ice', ...Map<String, dynamic>.from(data as Map)});
      })
      ..on('call:end', (data) {
        _callSignalStream.add({'event': 'call:end', ...Map<String, dynamic>.from(data as Map)});
      });
    _socket!.connect();
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
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
    _chatStream.close();
    _typingStream.close();
    _callSignalStream.close();
    _presenceStream.close();
    _appointmentBookedStream.close();
    _appointmentUpdatedStream.close();
    _chatRequestStream.close();
    _chatRequestResolvedStream.close();
  }
}
