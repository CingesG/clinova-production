import 'package:flutter/material.dart';

enum LogoVariant { light, dark, glass }

/// Reusable Clinova logo with responsive scaling and UI-friendly variants.
///
/// Mark assets: [LogoVariant.dark] uses `assets/branding/clinova_logo_ui.png` (lightweight UI
/// mark). Full-res `clinova_logo.png` remains for launcher icon generation only.
/// Light-on-dark heroes use `assets/images/clinova_logo_white.png`.
class ClinovaLogo extends StatelessWidget {
  const ClinovaLogo({
    super.key,
    this.size = 64,
    this.showText = true,
    this.variant = LogoVariant.dark,
    this.subtitle,
    this.responsive = true,
    this.assetPath,
  });

  final double size;
  final bool showText;
  final LogoVariant variant;
  final String? subtitle;
  final bool responsive;
  final String? assetPath;

  @override
  Widget build(BuildContext context) {
    final scaledSize = _resolveSize(context);
    final markSize = scaledSize.clamp(26.0, 88.0);
    // `glass` is used on dark hero cards: text must be light, not the same as `dark` (navy on navy).
    final brandColor = switch (variant) {
      LogoVariant.light => Colors.white,
      LogoVariant.glass => Colors.white,
      LogoVariant.dark => const Color(0xFF0A3B8F),
    };

    final mark = _LogoMark(
      size: markSize,
      assetPath: assetPath ?? _assetForVariant(variant),
      fallbackColor: brandColor,
    );

    if (!showText && subtitle == null) {
      return _wrapVariant(mark, variant);
    }

    final textBlock = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showText)
          Text(
            'Clinova',
            style: TextStyle(
              color: brandColor,
              fontSize: (markSize * 0.36).clamp(18.0, 34.0),
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              height: 1.05,
            ),
          ),
        if (subtitle != null)
          Text(
            subtitle!,
            style: TextStyle(
              color: brandColor.withValues(
                alpha: switch (variant) {
                  LogoVariant.dark => 0.72,
                  LogoVariant.light => 0.86,
                  LogoVariant.glass => 0.82,
                },
              ),
              fontSize: (markSize * 0.15).clamp(10.0, 13.0),
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );

    return _wrapVariant(
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          mark,
          const SizedBox(width: 10),
          Flexible(
            fit: FlexFit.loose,
            child: textBlock,
          ),
        ],
      ),
      variant,
    );
  }

  Widget _wrapVariant(Widget child, LogoVariant variant) {
    if (variant != LogoVariant.glass) return child;
    // Subtle frosted chip on dark heroes only — keep neutrals (no teal/green cast).
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: child,
    );
  }

  double _resolveSize(BuildContext context) {
    if (!responsive) return size;
    final width = MediaQuery.sizeOf(context).width;
    if (width < 420) return size * 0.86;
    if (width > 1440) return size * 1.08;
    return size;
  }

  String _assetForVariant(LogoVariant variant) => switch (variant) {
        LogoVariant.light => 'assets/images/clinova_logo_white.png',
        LogoVariant.glass => 'assets/images/clinova_logo_white.png',
        LogoVariant.dark => 'assets/branding/clinova_logo_ui.png',
      };
}

class _LogoMark extends StatelessWidget {
  const _LogoMark({
    required this.size,
    required this.assetPath,
    required this.fallbackColor,
  });

  final double size;
  final String assetPath;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final decode = (size * dpr).ceil().clamp(48, 256);
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        assetPath,
        fit: BoxFit.contain,
        cacheWidth: decode,
        cacheHeight: decode,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => Container(
          decoration: BoxDecoration(
            color: fallbackColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(size * 0.28),
          ),
          alignment: Alignment.center,
          child: Text(
            'C',
            style: TextStyle(
              fontSize: size * 0.45,
              fontWeight: FontWeight.w800,
              color: fallbackColor,
            ),
          ),
        ),
      ),
    );
  }
}
