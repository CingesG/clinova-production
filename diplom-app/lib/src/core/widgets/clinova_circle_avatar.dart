import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../media/clinova_avatar_url.dart';
import '../media/doctor_avatar_mapper.dart';

/// Neutral fill behind flat doctor illustrations (matches list cards).
const Color kClinovaFlatDoctorAvatarBackground = Color(0xFFE8EDF4);

/// Default radius for doctor list/card rows (home, directory strips).
const double kClinovaDoctorListAvatarRadius = 26;

/// Circle avatar with safe network/memory image loading; falls back to [initialsText]
/// on load error, invalid URL, or missing image (avoids [NetworkImage] throwing on web).
///
/// When [doctorPortraitFallback] is true, bundled flat doctor art is used instead of
/// initials (for network failure, missing URL, and loading placeholder on doctors).
///
/// When [doctorUseFlatAssetOnly] is true, only [kDoctorMaleAsset] / [kDoctorFemaleAsset]
/// are shown ([networkUrl] and legacy bundled paths are ignored).
class ClinovaCircleAvatar extends StatelessWidget {
  const ClinovaCircleAvatar({
    super.key,
    required this.radius,
    required this.initialsText,
    required this.backgroundColor,
    this.foregroundColor,
    this.networkUrl,
    this.memoryBytes,
    this.doctorPortraitFallback = false,
    this.doctorUseFlatAssetOnly = false,
    this.doctorDisplayName,
    this.doctorGender,
  });

  final double radius;
  final String initialsText;
  final Color backgroundColor;
  final Color? foregroundColor;
  final String? networkUrl;
  final Uint8List? memoryBytes;
  final bool doctorPortraitFallback;

  /// Doctor UI (cards, chat as seen by patient): never show real uploaded photos.
  final bool doctorUseFlatAssetOnly;
  final String? doctorDisplayName;
  final String? doctorGender;

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

  Widget _textFallback() {
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

  Widget _doctorFallback(BuildContext context) {
    final d = radius * 2;
    final px = _decodeExtent(context, d, 480);
    final path = resolveDoctorAvatar(
      doctorName: doctorDisplayName?.trim().isNotEmpty == true
          ? doctorDisplayName!
          : initialsText,
      gender: doctorGender,
    );
    return Image.asset(
      path,
      fit: BoxFit.cover,
      width: d,
      height: d,
      cacheWidth: px,
      cacheHeight: px,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => _textFallback(),
      frameBuilder: (context, child, frame, wasSync) {
        if (wasSync || frame != null) {
          return AnimatedOpacity(
            opacity: 1,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: child,
          );
        }
        return AnimatedOpacity(
          opacity: 0,
          duration: const Duration(milliseconds: 120),
          child: child,
        );
      },
    );
  }

  Widget _fallback(BuildContext context) {
    if (doctorPortraitFallback) {
      return _doctorFallback(context);
    }
    return _textFallback();
  }

  @override
  Widget build(BuildContext context) {
    final d = radius * 2;

    if (doctorUseFlatAssetOnly) {
      return SizedBox(
        width: d,
        height: d,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
          ),
          child: ClipOval(child: _doctorFallback(context)),
        ),
      );
    }

    final mem = memoryBytes;
    final hasMem = mem != null && mem.isNotEmpty;
    final trimmed = networkUrl?.trim();
    final bundledPath = !hasMem && trimmed != null && trimmed.isNotEmpty
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

    final Widget inner;
    if (hasMem) {
      inner = Image.memory(
        mem,
        fit: BoxFit.cover,
        width: d,
        height: d,
        errorBuilder: (_, _, _) => _fallback(context),
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
        errorBuilder: (_, _, _) => _fallback(context),
        frameBuilder: (context, child, frame, wasSync) {
          if (wasSync || frame != null) {
            return AnimatedOpacity(
              opacity: 1,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: child,
            );
          }
          return _fallback(context);
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
        placeholder: (context, url) => _fallback(context),
        errorWidget: (context, url, error) => _fallback(context),
      );
    } else {
      inner = _fallback(context);
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
