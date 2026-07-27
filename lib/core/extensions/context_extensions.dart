import 'package:flutter/material.dart';

/// Convenience extensions on BuildContext for quick theme access.
extension ContextExtensions on BuildContext {
  /// Quick access to the current [ThemeData].
  ThemeData get theme => Theme.of(this);

  /// Quick access to the current [ColorScheme].
  ColorScheme get colors => Theme.of(this).colorScheme;

  /// Quick access to the current [TextTheme].
  TextTheme get textStyles => Theme.of(this).textTheme;

  /// Quick access to [MediaQueryData].
  MediaQueryData get media => MediaQuery.of(this);

  /// Screen width.
  double get screenWidth => media.size.width;

  /// Screen height.
  double get screenHeight => media.size.height;

  /// Bottom padding (safe area).
  double get bottomPadding => media.padding.bottom;

  /// Top padding (safe area / status bar).
  double get topPadding => media.padding.top;

  /// Whether the device is in landscape orientation.
  bool get isLandscape => media.orientation == Orientation.landscape;

  /// Whether we're on a wide screen (tablet/desktop).
  bool get isWideScreen => screenWidth >= 600;

  /// Whether we're on a desktop-class screen.
  bool get isDesktop => screenWidth >= 1200;
}
