import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography — monochromatic palette edition.
/// Pure whites and greys on deep black backgrounds.
class AppTypography {
  AppTypography._();

  static TextTheme get textTheme {
    final base = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);

    return base.copyWith(
      // Display — large hero text
      displayLarge: GoogleFonts.outfit(
        fontSize: 48,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.5,
        color: Colors.white,
      ),
      displayMedium: GoogleFonts.outfit(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: Colors.white,
      ),
      displaySmall: GoogleFonts.outfit(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: Colors.white,
      ),

      // Headlines — section headers
      headlineLarge: GoogleFonts.outfit(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: Colors.white,
      ),
      headlineMedium: GoogleFonts.outfit(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: Colors.white,
      ),
      headlineSmall: GoogleFonts.outfit(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: Colors.white,
      ),

      // Titles — card headers, list items
      titleLarge: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: Colors.white,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: Colors.white,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: Colors.white,
      ),

      // Body — descriptions, metadata (mid-grey for hierarchy)
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.15,
        color: const Color(0xFFAAAAAA),
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.15,
        color: const Color(0xFFAAAAAA),
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.2,
        color: const Color(0xFF777777),
      ),

      // Labels — buttons, tabs, chips
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        color: Colors.white,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.4,
        color: const Color(0xFFAAAAAA),
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.4,
        color: const Color(0xFF777777),
      ),
    );
  }
}
