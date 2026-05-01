import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Нээлттэй байгаа `/doctor-chat` биш үед очсон [call:offer]-ийг дараагийн экран уншиж байгуулна.
final pendingInboundCallSignalProvider =
    StateProvider<Map<String, dynamic>?>((ref) => null);
