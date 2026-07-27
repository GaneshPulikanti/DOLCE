import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'color_schemes.dart';
import 'typography.dart';

/// App theme — monochromatic glassmorphism.
/// Deep black background, white glass surfaces, grey accents.
class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme => _buildTheme(AppColorSchemes.darkScheme);

  static ThemeData dynamicDarkTheme(Color seedColor) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    );
    return _buildTheme(colorScheme);
  }

  static ThemeData _buildTheme(ColorScheme colorScheme) {
    final textTheme = AppTypography.textTheme;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: Colors.transparent,

      // AppBar — transparent, no elevation
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      // Bottom Navigation — transparent (handled by custom frosted bar)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        indicatorColor: Colors.white.withValues(alpha: 0.10),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            );
          }
          return textTheme.labelSmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.4),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Colors.white, size: 24);
          }
          return IconThemeData(
            color: Colors.white.withValues(alpha: 0.4),
            size: 24,
          );
        }),
      ),

      // Cards — subtle glass surface
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.06),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.10),
            width: 0.8,
          ),
        ),
      ),

      // Bottom Sheet
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColorSchemes.surface1,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      // Slider — white track on black
      sliderTheme: SliderThemeData(
        activeTrackColor: Colors.white,
        inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
        thumbColor: Colors.white,
        overlayColor: Colors.white.withValues(alpha: 0.10),
        trackHeight: 2.5,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
      ),

      // Icon buttons
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: Colors.white),
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.08),
        thickness: 0.5,
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColorSchemes.surface2,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        behavior: kIsWeb ? SnackBarBehavior.fixed : SnackBarBehavior.floating,
        shape: kIsWeb ? null : RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // Switches
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.selected)
                  ? Colors.white
                  : const Color(0xFF555555),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.selected)
                  ? Colors.white.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.08),
        ),
      ),

      // Page transitions
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
