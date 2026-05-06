import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../media/clinova_avatar_url.dart';

/// Circle avatar with safe network/memory image loading; falls back to [initialsText]
/// on load error, invalid URL, or missing image (avoids [NetworkImage] throwing on web).
class ClinovaCircleAvatar extends StatelessWidget {
  const ClinovaCircleAvatar({
    super.key,
    required this.radius,
    required this.initialsText,
    required this.backgroundColor,
    this.foregroundColor,
    this.networkUrl,
    this.memoryBytes,
  });

  final double radius;
  final String initialsText;
  final Color backgroundColor;
  final Color? foregroundColor;
  final String? networkUrl;
  final Uint8List? memoryBytes;

  static bool _isLoadableHttpUrl(String s) {
    final u = Uri.tryParse(s.trim());
    return u != null &&
        u.hasScheme &&
        (u.isScheme('http') || u.isScheme('https'));
  }

  int _decodeExtent(BuildContext context, double logicalSide, int maxPx) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return (logicalSide * dpr).ceil().clamp(1, maxPx);
  }

  @override
  Widget build(BuildContext context) {
    final d = radius * 2;
    final mem = memoryBytes;
    final hasMem = mem != null && mem.isNotEmpty;
    final trimmed = networkUrl?.trim();
    final bundledPath = !hasMem &&
            trimmed != null &&
            trimmed.isNotEmpty
        ? clinovaBundledAvatarAssetPath(trimmed)
        : null;
    String? netUrl;
    if (!hasMem &&
        bundledPath == null &&
        trimmed != null &&
        trimmed.isNotEmpty &&
        _isLoadableHttpUrl(trimmed)) {
      netUrl = trimmed;
    }

    Widget fallback() {
      return Center(
        child: Text(
          initialsText,
          style: TextStyle(
            fontSize: radius * 0.55,
            fontWeight: FontWeight.w800,
            color: foregroundColor,
          ),
        ),
      );
    }

    final Widget inner;
    if (hasMem) {
      inner = Image.memory(
        mem,
        fit: BoxFit.cover,
        width: d,
        height: d,
        errorBuilder: (_, _, _) => fallback(),
      );
    } else if (bundledPath != null) {
      final px = _decodeExtent(context, d, 480);
      inner = Image.asset(
        bundledPath,
        fit: BoxFit.cover,
        width: d,
        height: d,
        cacheWidth: px,
        cacheHeight: px,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => fallback(),
        frameBuilder: (context, child, frame, wasSync) {
          if (wasSync || frame != null) {
            return child;
          }
          return fallback();
        },
      );
    } else if (netUrl != null) {
      final px = _decodeExtent(context, d, 512);
      inner = CachedNetworkImage(
        imageUrl: netUrl,
        fit: BoxFit.cover,
        width: d,
        height: d,
        memCacheWidth: px,
        memCacheHeight: px,
        fadeInDuration: const Duration(milliseconds: 200),
        fadeOutDuration: Duration.zero,
        placeholder: (context, url) => fallback(),
        errorWidget: (context, url, error) => fallback(),
      );
    } else {
      inner = fallback();
    }

    return SizedBox(
      width: d,
      height: d,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
        child: ClipOval(child: inner),
      ),
    );
  }
}
