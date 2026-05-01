import 'dart:typed_data';

import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    final d = radius * 2;
    final mem = memoryBytes;
    final hasMem = mem != null && mem.isNotEmpty;
    final trimmed = networkUrl?.trim();
    String? netUrl;
    if (!hasMem &&
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
    } else if (netUrl != null) {
      inner = Image.network(
        netUrl,
        fit: BoxFit.cover,
        width: d,
        height: d,
        errorBuilder: (_, _, _) => fallback(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return fallback();
        },
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
