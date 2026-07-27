import 'package:flutter/material.dart';

/// Color scheme — pure monochromatic black/charcoal/white palette.
/// Inspired by Daily UI #009: deep blacks, charcoal surfaces,
/// white glass panels. Zero hue — sleek, premium, minimal.
class AppColorSchemes {
  AppColorSchemes._();

  /// The default dark monochromatic scheme.
  static final ColorScheme darkScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF888888), // Neutral grey seed
    brightness: Brightness.dark,
  ).copyWith(
    // Fully transparent surfaces — background shows through glass
    surface: Colors.transparent,
    onSurface: const Color(0xFFF5F5F5),
    primary: const Color(0xFFFFFFFF),
    onPrimary: const Color(0xFF000000),
    secondary: const Color(0xFFBBBBBB),
    onSecondary: const Color(0xFF000000),
    surfaceContainerLowest: const Color(0x06FFFFFF),
    surfaceContainerLow: const Color(0x0AFFFFFF),
    surfaceContainer: const Color(0x10FFFFFF),
    surfaceContainerHigh: const Color(0x18FFFFFF),
    surfaceContainerHighest: const Color(0x22FFFFFF),
  );

  // ── Background palette (pure dark mono) ──────────────────────────────────
  /// Deep black — very top
  static const Color bgTop = Color(0xFF080808);

  /// Rich charcoal — upper mid
  static const Color bgMid = Color(0xFF111111);

  /// Medium charcoal — mid section
  static const Color bgAccent = Color(0xFF1A1A1A);

  /// Near-black — lower section
  static const Color bgLower = Color(0xFF0D0D0D);

  /// Pure black — bottom
  static const Color bgBottom = Color(0xFF050505);

  /// Subtle surface lift
  static const Color surface1 = Color(0xFF161616);
  static const Color surface2 = Color(0xFF1E1E1E);
  static const Color surface3 = Color(0xFF242424);

  // ── Fallback gradient ─────────────────────────────────────────────────────
  static const Color fallbackGradientStart = Color(0xFF111111);
  static const Color fallbackGradientEnd = Color(0xFF050505);

  // ── Accent (monochromatic) ────────────────────────────────────────────────
  /// Pure white — primary accent for icons, selected states
  static const Color accent = Color(0xFFFFFFFF);

  /// Dim white — secondary labels
  static const Color accentDim = Color(0xFF999999);

  /// Very dim white — tertiary/disabled
  static const Color accentFaint = Color(0xFF555555);

  // ── Glass fills (white on black = classic iOS glass) ─────────────────────
  /// Primary glass fill — subtle frosted white
  static Color glassFill = Colors.white.withValues(alpha: 0.08);

  /// Light glass fill — very subtle, for nested elements
  static Color glassFillLight = Colors.white.withValues(alpha: 0.05);

  /// Strong glass fill — more opaque panels
  static Color glassFillStrong = Colors.white.withValues(alpha: 0.13);

  /// Glass border — crisp white hairline
  static Color glassBorder = Colors.white.withValues(alpha: 0.14);

  /// Subtle border — barely visible
  static Color glassBorderSubtle = Colors.white.withValues(alpha: 0.08);

  /// Top-left highlight gradient — gives glass its 3D shimmer
  static Color glassHighlight = Colors.white.withValues(alpha: 0.18);

  // ── Backward compatibility ────────────────────────────────────────────────
  static Color glassOverlay = Colors.white.withValues(alpha: 0.06);
  static Color glassOverlayStrong = Colors.white.withValues(alpha: 0.12);

  // ── Scenic aliases (required by gradient_background.dart) ────────────────
  static const Color scenicTop = bgTop;
  static const Color scenicMid = bgMid;
  static const Color scenicAccent = surface2;
  static const Color scenicBottom = bgBottom;
  static const Color scenicMountain = surface1;
  static const Color scenicSky = bgAccent;
}
