import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../theme/color_schemes.dart';

/// Dark monochromatic background — deep blacks with subtle grey vignette.
/// Matches the Daily UI #009 color palette: pure dark, no hue.
/// All glass panels float on top of this ultra-dark surface.
class ScenicBackground extends StatelessWidget {
  final Widget child;

  const ScenicBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        // Deep black → charcoal gradient, top to bottom
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColorSchemes.bgTop, // #080808 — near-black top
            AppColorSchemes.bgMid, // #111111 — charcoal
            AppColorSchemes.bgAccent, // #1A1A1A — mid charcoal
            AppColorSchemes.bgLower, // #0D0D0D — darker again
            AppColorSchemes.bgBottom, // #050505 — pure black bottom
          ],
          stops: [0.0, 0.25, 0.5, 0.75, 1.0],
        ),
      ),
      child: CustomPaint(painter: _MonoPainter(), child: child),
    );
  }
}

/// Paints subtle monochromatic texture — soft vignette and grey radial glow.
/// Keeps the dark background visually interesting without adding colour.
class _MonoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    _paintRadialGlow(canvas, size);
    _paintSubtleNoise(canvas, size);
    _paintBottomVignette(canvas, size);
  }

  /// Soft grey radial glow in upper center — like a backlit screen.
  void _paintRadialGlow(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(0.0, -0.5),
            radius: 0.9,
            colors: [Colors.white.withValues(alpha: 0.04), Colors.transparent],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  /// Very faint horizontal bands — gives depth without colour.
  void _paintSubtleNoise(Canvas canvas, Size size) {
    final rng = math.Random(99);
    for (int i = 0; i < 6; i++) {
      final y = size.height * (0.1 + i * 0.14);
      final alpha = rng.nextDouble() * 0.015;
      final paint =
          Paint()
            ..color = Colors.white.withValues(alpha: alpha)
            ..strokeWidth = 0.5
            ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  /// Dark gradient at the bottom — pulls the eye up.
  void _paintBottomVignette(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.5)],
            stops: const [0.6, 1.0],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
