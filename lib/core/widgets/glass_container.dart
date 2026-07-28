import 'dart:ui';
import 'package:flutter/material.dart';

import '../constants/ui_constants.dart';
import '../theme/color_schemes.dart';

/// iOS-style frosted glass container — monochromatic edition.
/// White glass on deep black: clean, refined, not heavy.
///
/// Blur is intentionally moderate (12–18σ) to avoid the "foggy" look.
/// The fill is a crisp white-on-black frost, with a sharp hairline border.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blurSigma;
  final Color? fillColor;
  final Color? borderColor;
  final double borderWidth;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final bool showHighlight;
  final BoxShape shape;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = UIConstants.radiusXXL,
    this.blurSigma = 16.0, // moderate — crisp not foggy
    this.fillColor,
    this.borderColor,
    this.borderWidth = 0.8, // hairline border
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.showHighlight = true,
    this.shape = BoxShape.rectangle,
  });

  /// Light variant — for chips, tags, small pills.
  const GlassContainer.light({
    super.key,
    required this.child,
    this.borderRadius = UIConstants.radiusXL,
    this.blurSigma = 12.0,
    this.fillColor,
    this.borderColor,
    this.borderWidth = 0.8,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.showHighlight = false,
    this.shape = BoxShape.rectangle,
  });

  /// Strong variant — panels, drawers, bottom sheets.
  const GlassContainer.strong({
    super.key,
    required this.child,
    this.borderRadius = UIConstants.radiusXXXL,
    this.blurSigma = 20.0,
    this.fillColor,
    this.borderColor,
    this.borderWidth = 1.0,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.showHighlight = true,
    this.shape = BoxShape.rectangle,
  });

  @override
  Widget build(BuildContext context) {
    final fill = fillColor ?? AppColorSchemes.glassFill;
    final border = borderColor ?? AppColorSchemes.glassBorder;
    final isCircle = shape == BoxShape.circle;
    final radius = BorderRadius.circular(isCircle ? 999 : borderRadius);
    final effectiveBlur = blurSigma.clamp(0.0, 10.0);

    return Container(
      margin: margin,
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: effectiveBlur, sigmaY: effectiveBlur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: radius,
              // Glass fill: white-on-black frost
              color: showHighlight ? null : fill,
              gradient:
                  showHighlight
                      ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          // Top-left: slightly brighter (light hits the glass)
                          Colors.white.withValues(alpha: (fill.a / 255) + 0.06),
                          fill,
                          fill.withValues(alpha: fill.a / 255 * 0.8),
                        ],
                        stops: const [0.0, 0.4, 1.0],
                      )
                      : null,
              border: Border.all(color: border, width: borderWidth),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
