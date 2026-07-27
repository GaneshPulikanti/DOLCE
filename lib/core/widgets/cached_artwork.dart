import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../constants/ui_constants.dart';

/// A reusable cached artwork widget with shimmer placeholder and error state.
/// Used for album covers, artist images, and playlist art throughout the app.
class CachedArtwork extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final double borderRadius;
  final BoxFit fit;
  final IconData fallbackIcon;

  const CachedArtwork({
    super.key,
    required this.imageUrl,
    this.size = UIConstants.albumArtSizeMd,
    this.borderRadius = UIConstants.radiusMD,
    this.fit = BoxFit.cover,
    this.fallbackIcon = Icons.music_note_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: size,
        height: size,
        child:
            imageUrl != null && imageUrl!.isNotEmpty
                ? CachedNetworkImage(
                  imageUrl: imageUrl!,
                  width: size,
                  height: size,
                  fit: fit,
                  placeholder: (context, url) => _buildPlaceholder(colorScheme),
                  errorWidget:
                      (context, url, error) => _buildError(colorScheme),
                )
                : _buildError(colorScheme),
      ),
    );
  }

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerHigh,
      child: Center(
        child: SizedBox(
          width: size * 0.3,
          height: size * 0.3,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: colorScheme.primary.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildError(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerHigh,
      child: Center(
        child: Icon(
          fallbackIcon,
          size: size * 0.35,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
