// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

class HeroBackgroundVideo extends StatefulWidget {
  const HeroBackgroundVideo({
    required this.assetPath,
    required this.posterPath,
    super.key,
  });

  final String assetPath;
  final String posterPath;

  @override
  State<HeroBackgroundVideo> createState() => _HeroBackgroundVideoState();
}

class _HeroBackgroundVideoState extends State<HeroBackgroundVideo> {
  static int _counter = 0;
  late final String _viewType;

  /// Flutter web copies `pubspec` assets to `build/web/assets/assets/...` when
  /// the manifest key is `assets/...`. Raw `assets/videos/x` 404s; use the
  /// double-`assets` URL relative to [html.document.baseUri].
  static String _webBundledAssetUrl(String manifestKey) {
    if (!manifestKey.startsWith('assets/')) return manifestKey;
    return 'assets/assets/${manifestKey.substring(7)}';
  }

  @override
  void initState() {
    super.initState();
    _viewType = 'clinova-hero-bg-video-${_counter++}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final base = Uri.parse(html.document.baseUri ?? html.window.location.href);
      final src = base.resolve(_webBundledAssetUrl(widget.assetPath)).toString();
      final poster = base.resolve(_webBundledAssetUrl(widget.posterPath)).toString();
      final video = html.VideoElement()
        ..autoplay = true
        ..muted = true
        ..loop = true
        ..controls = false
        ..src = src
        ..poster = poster;
      video.style
        ..width = '100%'
        ..height = '100%'
        ..objectFit = 'cover'
        ..objectPosition = 'center center'
        ..filter = 'saturate(1.05) brightness(0.9)'
        ..pointerEvents = 'none';
      video.setAttribute('preload', 'auto');
      video.setAttribute('playsinline', 'true');
      video.setAttribute('aria-hidden', 'true');
      video.onCanPlay.listen((_) {
        video.play();
      });
      return video;
    });
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}
