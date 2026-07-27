import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../constants/ui_constants.dart';

/// Shimmer loading skeleton for various content types.
class ShimmerLoading extends StatelessWidget {
  final Widget child;

  const ShimmerLoading({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Shimmer.fromColors(
      baseColor: colorScheme.surfaceContainerHigh,
      highlightColor: colorScheme.surfaceContainerHighest,
      child: child,
    );
  }

  /// A horizontal list of card-shaped shimmer placeholders.
  static Widget horizontalCardList({
    int itemCount = 5,
    double itemWidth = 150,
    double itemHeight = 200,
  }) {
    return SizedBox(
      height: itemHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: UIConstants.spaceLG),
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(width: UIConstants.spaceMD),
        itemBuilder:
            (context, index) => ShimmerLoading(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: itemWidth,
                    height: itemWidth,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(UIConstants.radiusMD),
                    ),
                  ),
                  const SizedBox(height: UIConstants.spaceSM),
                  Container(
                    width: itemWidth * 0.7,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(UIConstants.radiusSM),
                    ),
                  ),
                  const SizedBox(height: UIConstants.spaceXS),
                  Container(
                    width: itemWidth * 0.5,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(UIConstants.radiusSM),
                    ),
                  ),
                ],
              ),
            ),
      ),
    );
  }

  /// A list tile shimmer placeholder.
  static Widget listTile() {
    return ShimmerLoading(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: UIConstants.spaceLG,
          vertical: UIConstants.spaceSM,
        ),
        child: Row(
          children: [
            Container(
              width: UIConstants.albumArtSizeMd,
              height: UIConstants.albumArtSizeMd,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(UIConstants.radiusMD),
              ),
            ),
            const SizedBox(width: UIConstants.spaceMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(UIConstants.radiusSM),
                    ),
                  ),
                  const SizedBox(height: UIConstants.spaceSM),
                  Container(
                    width: 120,
                    height: 11,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(UIConstants.radiusSM),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
