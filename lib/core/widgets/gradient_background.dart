import 'package:flutter/material.dart';

import '../theme/color_schemes.dart';

/// Gradient background — monochromatic edition.
/// Deep black to charcoal gradient for album/player detail screens.
class GradientBackground extends StatelessWidget {
  final Color? primaryColor;
  final Widget child;
  final double opacity;
  final List<AlignmentGeometry>? stops;

  const GradientBackground({
    super.key,
    this.primaryColor,
    required this.child,
    this.opacity = 0.6,
    this.stops,
  });

  @override
  Widget build(BuildContext context) {
    // For mono theme: use the provided color as a very subtle tint,
    // but desaturate it toward grey to maintain the monochromatic feel.
    final color =
        primaryColor != null
            ? _toGrey(primaryColor!)
            : AppColorSchemes.fallbackGradientStart;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: stops?[0] ?? Alignment.topCenter,
          end: stops?[1] ?? Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: opacity * 0.6),
            color.withValues(alpha: opacity * 0.25),
            AppColorSchemes.bgBottom,
          ],
          stops: const [0.0, 0.4, 1.0],
        ),
      ),
      child: child,
    );
  }

  /// Desaturate a color toward grey while preserving luminance.
  Color _toGrey(Color c) {
    final luminance = (c.r * 0.299 + c.g * 0.587 + c.b * 0.114);
    final grey = luminance.round();
    return Color.fromRGBO(grey, grey, grey, 1.0);
  }
}
