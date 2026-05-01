import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

/// Looped ringtone: system ringtone on Android/iOS, asset loop on Web/desktop.
Future<void> startClinovaCallRingtone() async {
  if (kIsWeb) {
    final p = AudioPlayer();
    await p.setReleaseMode(ReleaseMode.loop);
    await p.play(AssetSource('sounds/ring.wav'));
    _webPlayer ??= p;
    return;
  }
  await FlutterRingtonePlayer().stop();
  await FlutterRingtonePlayer().play(
    fromAsset: 'assets/sounds/ring.wav',
    looping: true,
  );
}

Future<void> stopClinovaCallRingtone() async {
  final p = _webPlayer;
  if (p != null) {
    await p.stop();
    await p.dispose();
    _webPlayer = null;
  }
  if (!kIsWeb) {
    try {
      await FlutterRingtonePlayer().stop();
    } catch (_) {}
  }
}

AudioPlayer? _webPlayer;
