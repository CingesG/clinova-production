import 'package:flutter/material.dart';

class ClinovaBackdrop extends StatelessWidget {
  const ClinovaBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF8FBFC), Color(0xFFF2F5FA)],
        ),
      ),
      child: Stack(
        children: [
          const Positioned(
            top: -96,
            left: -56,
            child: _GlowOrb(size: 240, color: Color(0xFFCBD5E1)),
          ),
          const Positioned(
            top: 180,
            right: -64,
            child: _GlowOrb(size: 220, color: Color(0xFF60A5FA)),
          ),
          const Positioned(
            bottom: -120,
            left: -32,
            child: _GlowOrb(size: 260, color: Color(0xFF2DD4BF)),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.26),
              color.withValues(alpha: 0.06),
              color.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    );
  }
}
