import 'package:flutter_riverpod/flutter_riverpod.dart';

/// User ids currently reported as online via Socket.IO `presence:changed`.
final onlineUserIdsProvider =
    NotifierProvider<OnlineUserIdsNotifier, Set<String>>(
  OnlineUserIdsNotifier.new,
);

class OnlineUserIdsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};

  void applyPresence({required String userId, required String status}) {
    final u = userId.trim();
    if (u.isEmpty) return;
    final next = {...state};
    if (status == 'online') {
      next.add(u);
    } else {
      next.remove(u);
    }
    state = next;
  }
}
