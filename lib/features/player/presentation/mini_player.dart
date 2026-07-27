import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audio_service/audio_service.dart';

import 'package:go_router/go_router.dart';

import '../../../core/theme/color_schemes.dart';
import '../../../core/widgets/glass_container.dart';
import '../providers/player_provider.dart';

class MiniPlayerPlaceholder extends ConsumerWidget {
  const MiniPlayerPlaceholder({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackAsync = ref.watch(currentTrackProvider);
    final playbackStateAsync = ref.watch(playbackStateProvider);
    final isLoadingTrack = ref.watch(isLoadingTrackProvider);
    final restoredTrack = ref.watch(restoredSessionTrackProvider);
    final restoredPosition = ref.watch(restoredSessionPositionProvider);

    final liveTrack = trackAsync.value;

    // Resolve which track to display: live → restored → nothing
    final displayTrack = liveTrack ?? restoredTrack;
    final isRestored = liveTrack == null && restoredTrack != null;

    final isPlaying = playbackStateAsync.value?.playing ?? false;
    final processingState = playbackStateAsync.value?.processingState ??
        AudioProcessingState.idle;
    final isBuffering = processingState == AudioProcessingState.loading ||
        processingState == AudioProcessingState.buffering;

    return GestureDetector(
      onTap: displayTrack != null ? () => context.push('/player') : null,
      child: AnimatedOpacity(
        opacity: 1.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          height: 64,
          child: GlassContainer(
            fillColor: displayTrack != null
                ? AppColorSchemes.surface1
                : Colors.white.withValues(alpha: 0.03),
            borderColor: displayTrack != null
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.04),
            blurSigma: 15,
            borderRadius: 32,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: displayTrack == null
                  ? _GhostState()
                  : Row(
                      children: [
                        // ── Artwork ──
                        _Artwork(
                          track: displayTrack,
                          isLoading: isLoadingTrack && liveTrack == null,
                          isRestored: isRestored,
                        ),
                        const SizedBox(width: 12),

                        // ── Title + subtitle ──
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                displayTrack.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                isLoadingTrack && liveTrack == null
                                    ? 'Finding stream...'
                                    : isBuffering
                                        ? 'Buffering...'
                                        : isRestored
                                            ? '${displayTrack.artistName}  ·  ${_formatDuration(restoredPosition)}'
                                            : displayTrack.artistName,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: (isLoadingTrack && liveTrack == null) ||
                                              isBuffering
                                          ? Colors.amber.withValues(alpha: 0.7)
                                          : Colors.white.withValues(alpha: 0.6),
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        // ── Controls ──
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isRestored)
                              IconButton(
                                icon: const Icon(
                                  Icons.skip_previous_rounded,
                                  color: Colors.white70,
                                  size: 22,
                                ),
                                onPressed: () {
                                  ref
                                      .read(playerHandlerProvider)
                                      .skipToPrevious();
                                },
                              ),
                            if ((isLoadingTrack && liveTrack == null) ||
                                isBuffering)
                              const Padding(
                                padding:
                                    EdgeInsets.symmetric(horizontal: 12),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.0,
                                    color: Colors.white70,
                                  ),
                                ),
                              )
                            else
                              IconButton(
                                icon: Icon(
                                  isRestored
                                      ? Icons.play_circle_fill_rounded
                                      : isPlaying
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                  color: isRestored
                                      ? Colors.white
                                      : Colors.white,
                                  size: isRestored ? 30 : 26,
                                ),
                                onPressed: () {
                                  final handler =
                                      ref.read(playerHandlerProvider);
                                  final rTrack = restoredTrack;
                                  if (isRestored && rTrack != null) {
                                    // Resume from saved position
                                    handler.playTrack(
                                      rTrack,
                                      initialPosition: restoredPosition,
                                      shouldPlay: true,
                                    );
                                  } else if (isPlaying) {
                                    handler.pause();
                                  } else {
                                    handler.play();
                                  }
                                },
                              ),
                            if (!isRestored)
                              IconButton(
                                icon: const Icon(
                                  Icons.skip_next_rounded,
                                  color: Colors.white70,
                                  size: 22,
                                ),
                                onPressed: () {
                                  ref
                                      .read(playerHandlerProvider)
                                      .skipToNext();
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ─── Ghost state widget (nothing playing yet) ────────────────────────────────

class _GhostState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.white.withValues(alpha: 0.05),
          ),
          child: const Icon(
            Icons.music_note_rounded,
            color: Colors.white24,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Play something to start listening',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white24,
                  fontStyle: FontStyle.italic,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const Icon(
          Icons.equalizer_rounded,
          color: Colors.white12,
          size: 22,
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

// ─── Artwork widget ───────────────────────────────────────────────────────────

class _Artwork extends StatelessWidget {
  final dynamic track;
  final bool isLoading;
  final bool isRestored;

  const _Artwork({
    required this.track,
    required this.isLoading,
    required this.isRestored,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 40,
          height: 40,
          color: Colors.white.withValues(alpha: 0.1),
          child: const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white70,
              ),
            ),
          ),
        ),
      );
    }

    if (track.artworkUrl != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: track.artworkUrl!,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
          if (isRestored)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.black.withValues(alpha: 0.35),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  color: Colors.white60,
                  size: 16,
                ),
              ),
            ),
        ],
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 40,
        height: 40,
        color: Colors.white.withValues(alpha: 0.1),
        child: const Icon(
          Icons.music_note_rounded,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
}
