import 'package:flutter/material.dart';

import '../constants/ui_constants.dart';

/// A responsive layout builder that provides different layouts
/// based on screen width breakpoints (mobile, tablet, desktop).
class ResponsiveLayout extends StatelessWidget {
  /// Required: Layout for mobile screens (< 600dp).
  final Widget mobile;

  /// Optional: Layout for tablet screens (600-1200dp).
  /// Falls back to [mobile] if not provided.
  final Widget? tablet;

  /// Optional: Layout for desktop screens (> 1200dp).
  /// Falls back to [tablet] or [mobile] if not provided.
  final Widget? desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= UIConstants.desktopBreakpoint) {
          return desktop ?? tablet ?? mobile;
        }
        if (constraints.maxWidth >= UIConstants.mobileBreakpoint) {
          return tablet ?? mobile;
        }
        return mobile;
      },
    );
  }

  /// Returns the current layout type based on screen width.
  static LayoutType getLayoutType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= UIConstants.desktopBreakpoint) return LayoutType.desktop;
    if (width >= UIConstants.mobileBreakpoint) return LayoutType.tablet;
    return LayoutType.mobile;
  }
}

enum LayoutType { mobile, tablet, desktop }
