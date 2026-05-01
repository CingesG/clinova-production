import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

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
  VideoPlayerController? _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    final controller = VideoPlayerController.asset(widget.assetPath);
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _ready = true;
      });
    } catch (_) {
      await controller.dispose();
      if (!mounted) return;
      setState(() {
        _controller = null;
        _ready = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ready && _controller != null) {
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _controller!.value.size.width,
            height: _controller!.value.size.height,
            child: VideoPlayer(_controller!),
          ),
        ),
      );
    }
    return Image.asset(
      widget.posterPath,
      fit: BoxFit.cover,
      errorBuilder: (_, error, stackTrace) =>
          const ColoredBox(color: Color(0xFF0B5FA8)),
    );
  }
}
