import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

/// Extracts dominant colors from album art images for dynamic theming.
class ImageColorExtractor {
  ImageColorExtractor._();

  /// Extracts the dominant color from a network image URL.
  /// Returns the dominant color, or a fallback if extraction fails.
  static Future<Color> extractDominantColor(
    String imageUrl, {
    Color fallback = const Color(0xFF1DB954),
  }) async {
    try {
      final paletteGenerator = await PaletteGenerator.fromImageProvider(
        NetworkImage(imageUrl),
        size: const Size(100, 100), // Use small size for performance
        maximumColorCount: 8,
      );

      // Prefer vibrant, fall back to dominant, then muted
      return paletteGenerator.vibrantColor?.color ??
          paletteGenerator.dominantColor?.color ??
          paletteGenerator.mutedColor?.color ??
          fallback;
    } catch (_) {
      return fallback;
    }
  }

  /// Extracts a full color palette from a network image.
  /// Returns a map of palette categories for more nuanced theming.
  static Future<Map<String, Color?>> extractPalette(String imageUrl) async {
    try {
      final paletteGenerator = await PaletteGenerator.fromImageProvider(
        NetworkImage(imageUrl),
        size: const Size(100, 100),
        maximumColorCount: 16,
      );

      return {
        'vibrant': paletteGenerator.vibrantColor?.color,
        'darkVibrant': paletteGenerator.darkVibrantColor?.color,
        'lightVibrant': paletteGenerator.lightVibrantColor?.color,
        'muted': paletteGenerator.mutedColor?.color,
        'darkMuted': paletteGenerator.darkMutedColor?.color,
        'lightMuted': paletteGenerator.lightMutedColor?.color,
        'dominant': paletteGenerator.dominantColor?.color,
      };
    } catch (_) {
      return {};
    }
  }
}
