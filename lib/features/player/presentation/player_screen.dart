import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:audio_service/audio_service.dart';


import '../../../core/theme/color_schemes.dart';
import '../../youtube/data/models/youtube_track.dart';
import '../../youtube/providers/youtube_providers.dart';
import '../providers/player_provider.dart';
import '../../library/providers/local_library_provider.dart';
import '../../library/presentation/local_playlist_dialogs.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  final ScrollController _previewLyricsScrollController = ScrollController();
  int _lastPreviewActiveLyricIndex = -1;
  Timer? _previewLyricsFallbackTimer;
  bool _isUserScrollingPreview = false;
  bool _isManualScrollInProgress = false;
  final ScrollController _pageScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _previewLyricsFallbackTimer?.cancel();
    _pageScrollController.dispose();
    _previewLyricsScrollController.dispose();
    super.dispose();
  }

  void _scrollToActivePreviewLyric(int index, int totalLines) {
    if (_isUserScrollingPreview) return;
    if (index == _lastPreviewActiveLyricIndex || !_previewLyricsScrollController.hasClients) return;
    _lastPreviewActiveLyricIndex = index;

    const double itemHeight = 44.0;
    final double targetOffset = index * itemHeight;

    _previewLyricsScrollController.animateTo(
      targetOffset.clamp(0.0, _previewLyricsScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 600), // buttery smooth transition
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final trackAsync = ref.watch(currentTrackProvider);
    final playbackStateAsync = ref.watch(playbackStateProvider);
    final isLoadingTrack = ref.watch(isLoadingTrackProvider);

    final track = trackAsync.value;
    final isPlaying = playbackStateAsync.value?.playing ?? false;
    final stateVal = playbackStateAsync.value;
    final isBuffering = isLoadingTrack ||
        stateVal?.processingState == AudioProcessingState.buffering ||
        stateVal?.processingState == AudioProcessingState.loading;

    final paletteAsync = ref.watch(currentTrackPaletteProvider);
    final palette = paletteAsync.value ?? {};
    final bgColor = palette['darkMuted'] ?? palette['darkVibrant'] ?? palette['dominant']?.withValues(alpha: 0.8) ?? AppColorSchemes.bgMid;
    final accentColor = palette['vibrant'] ?? palette['lightVibrant'] ?? palette['dominant'] ?? Colors.white;



    if (track == null && !isLoadingTrack) {
      return Scaffold(
        backgroundColor: AppColorSchemes.bgBottom,
        body: const Center(
          child: Text(
            'No song playing',
            style: TextStyle(color: Colors.white70, fontFamily: 'Inter'),
          ),
        ),
      );
    }

    final artworkUrl = track?.artworkUrl;

    return Scaffold(
      body: Stack(
        children: [
          // ── Dynamic Glassmorphic Ambient Artwork Background ──
          Positioned.fill(
            child: Container(
              color: AppColorSchemes.bgBottom,
            ),
          ),
          if (artworkUrl != null) ...[
            Positioned.fill(
              child: Opacity(
                opacity: 0.55,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 45, sigmaY: 45),
                  child: CachedNetworkImage(
                    imageUrl: artworkUrl,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          bgColor.withValues(alpha: 0.35),
                          bgColor.withValues(alpha: 0.70),
                          bgColor.withValues(alpha: 0.90),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ] else ...[
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.35),
                      AppColorSchemes.bgBottom.withValues(alpha: 0.88),
                      AppColorSchemes.bgBottom,
                    ],
                  ),
                ),
              ),
            ),
          ],

          // ── Scrollable Player Page with Unified Lyrics expansion ──
          LayoutBuilder(
            builder: (context, constraints) {
              final screenHeight = constraints.maxHeight;
              final mainContentHeight = screenHeight - 140; // 140 is the height of collapsed lyrics card showing at bottom

              return SingleChildScrollView(
                controller: _pageScrollController,
                physics: const ClampingScrollPhysics(),
                child: Column(
                  children: [
                    // Panel 1: Main Player
                    SizedBox(
                      height: mainContentHeight,
                      child: SafeArea(
                        bottom: false,
                        child: Column(
                          children: [
                            _buildHeaderWithToggle(context, track),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildArtOrVideoContainer(track),
                                    _buildMetadataBlock(context, track),
                                    _buildProgressBar(context),
                                    _buildPlaybackControlsRow(isPlaying, isBuffering, track),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Panel 2: Lyrics Container (expansion area)
                    if (track != null)
                      Container(
                        height: 350,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: _buildLyricsPreviewContainer(context, track, accentColor, bgColor, screenHeight),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Header Widget ──
  Widget _buildHeaderWithToggle(BuildContext context, YoutubeTrack? track) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 30),
            onPressed: () => context.pop(),
          ),

          const Text(
            'NOW PLAYING',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
              color: Colors.white70,
            ),
          ),

          if (track != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
              color: AppColorSchemes.bgMid,
              onSelected: (value) async {
                if (value == 'favorite') {
                  ref.read(localLibraryProvider.notifier).toggleFavorite(track);
                } else if (value == 'playlist') {
                  showAddToPlaylistSheet(context, ref, track);
                } else if (value == 'download') {
                  final notifier = ref.read(localLibraryProvider.notifier);
                  final isDownloaded = notifier.isDownloaded(track.id);
                  if (isDownloaded) {
                    await notifier.removeDownload(track.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Song removed from downloads')),
                    );
                  } else {
                    await notifier.addDownload(track);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Song downloaded successfully!')),
                    );
                  }
                }
              },
              itemBuilder: (context) {
                final isFav = ref.read(localLibraryProvider.notifier).isFavorite(track.id);
                final isDown = ref.read(localLibraryProvider.notifier).isDownloaded(track.id);
                return [
                  PopupMenuItem(
                    value: 'favorite',
                    child: Row(
                      children: [
                        Icon(isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: isFav ? Colors.redAccent : Colors.white70, size: 18),
                        const SizedBox(width: 8),
                        Text(isFav ? 'Remove Favorite' : 'Add to Favorites', style: const TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'playlist',
                    child: Row(
                      children: const [
                        Icon(Icons.playlist_add_rounded, color: Colors.white70, size: 18),
                        const SizedBox(width: 8),
                        Text('Add to Playlist', style: TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'download',
                    child: Row(
                      children: [
                        Icon(isDown ? Icons.download_done_rounded : Icons.download_rounded, color: isDown ? Colors.green : Colors.white70, size: 18),
                        const SizedBox(width: 8),
                        Text(isDown ? 'Remove Download' : 'Download Song', style: const TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                ];
              },
            )
          else
            const IconButton(
              icon: Icon(Icons.more_vert_rounded, color: Colors.white30),
              onPressed: null,
            ),
        ],
      ),
    );
  }

  // ── Art Container ──
  Widget _buildArtOrVideoContainer(YoutubeTrack? track) {
    return Center(
      child: Container(
        width: 280,
        height: 280,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1.0,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: track?.artworkUrl != null
              ? CachedNetworkImage(
                  imageUrl: track!.artworkUrl!,
                  width: 280,
                  height: 280,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                )
              : Container(
                  color: AppColorSchemes.surface2,
                  child: const Icon(Icons.music_note_rounded, size: 70, color: Colors.white24),
                ),
        ),
      ),
    ).animate().scale(delay: 50.ms, duration: 350.ms, curve: Curves.easeOutBack);
  }

  // ── Vertically Stacked Metadata ──
  Widget _buildMetadataBlock(BuildContext context, YoutubeTrack? track) {
    final t = track;
    if (t == null) {
      return Column(
        children: const [
          Text(
            'Loading...',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    final localState = ref.watch(localLibraryProvider);
    final isFav = localState.favorites.any((s) => s.id == t.id);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: isFav ? Colors.redAccent : Colors.white70,
              size: 26,
            ),
            onPressed: () {
              ref.read(localLibraryProvider.notifier).toggleFavorite(t);
            },
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  t.title,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // Singer / Composer Name (Middle line)
                GestureDetector(
                  onTap: () {
                    final cleanName = t.artistName.replaceAll(' - Topic', '').trim();
                    final id = (t.artistId != null && t.artistId!.trim().isNotEmpty && t.artistId != 'null')
                        ? t.artistId!
                        : cleanName.replaceAll(' ', '_');
                    context.push('/artist/$id');
                  },
                  child: Text(
                    t.artistName,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 4),

                // Movie / Album Name (Bottom line)
                if (t.albumName != null)
                  GestureDetector(
                    onTap: () {
                      if (t.albumId != null) {
                        context.push('/album/${t.albumId}');
                      }
                    },
                    child: Text(
                      t.albumName!,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.playlist_add_rounded,
              color: Colors.white70,
              size: 28,
            ),
            onPressed: () {
              showAddToPlaylistSheet(context, ref, t);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPlaybackControlsRow(bool isPlaying, bool isBuffering, YoutubeTrack? track) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: _buildCycleIcon(ref),
          onPressed: () {
            ref.read(playerHandlerProvider).cyclePlaybackMode();
          },
        ),
        IconButton(
          icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 36),
          onPressed: () => ref.read(playerHandlerProvider).skipToPrevious(),
        ),
        GestureDetector(
          onTap: () {
            final handler = ref.read(playerHandlerProvider);
            if (isPlaying) {
              handler.pause();
            } else {
              handler.play();
            }
          },
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: isBuffering
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                    )
                  : Icon(
                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.black,
                      size: 34,
                    ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 36),
          onPressed: () => ref.read(playerHandlerProvider).skipToNext(),
        ),
        IconButton(
          icon: const Icon(Icons.queue_music_rounded, color: Colors.white70, size: 24),
          onPressed: () => _showQueueBottomSheet(context, track?.id),
        ),
      ],
    );
  }

  // Real-time progress bar
  Widget _buildProgressBar(BuildContext context) {
    final positionAsync = ref.watch(playerPositionProvider);
    final durationAsync = ref.watch(playerDurationProvider);

    final position = positionAsync.value ?? Duration.zero;
    final duration = durationAsync.value ?? const Duration(minutes: 3);

    double progress = 0.0;
    if (duration.inMilliseconds > 0) {
      progress = position.inMilliseconds / duration.inMilliseconds;
    }
    progress = progress.clamp(0.0, 1.0);

    String formatDuration(Duration d) {
      final mins = d.inMinutes;
      final secs = d.inSeconds % 60;
      return '$mins:${secs.toString().padLeft(2, '0')}';
    }

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3.0,
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
            thumbColor: Colors.white,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.5),
            overlayColor: Colors.white.withValues(alpha: 0.15),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          ),
          child: Slider(
            value: progress,
            onChangeEnd: (val) {
              final targetMs = (val * duration.inMilliseconds).toInt();
              final handler = ref.read(playerHandlerProvider);
              handler.seek(Duration(milliseconds: targetMs));
              handler.play(); // Force continue playing after seek completes!
            },
            onChanged: (val) {
              final targetMs = (val * duration.inMilliseconds).toInt();
              ref.read(playerHandlerProvider).seek(Duration(milliseconds: targetMs));
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formatDuration(position),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                formatDuration(duration),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Combined mode icon builder
  Widget _buildCycleIcon(WidgetRef ref) {
    final handler = ref.watch(playerHandlerProvider);
    if (handler.isShuffleEnabled) {
      return const Icon(Icons.shuffle_rounded, color: Colors.white, size: 22);
    } else if (handler.isLoopOneEnabled) {
      return const Icon(Icons.repeat_one_rounded, color: Colors.white, size: 22);
    } else {
      return Icon(Icons.repeat_rounded, color: Colors.white.withValues(alpha: 0.4), size: 22);
    }
  }
  void _openFullScreenLyrics(BuildContext context, YoutubeTrack track, Color bgColor, Color accentColor) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FullScreenLyricsPage(
            bgColor: bgColor,
            accentColor: accentColor,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOutCubic,
              ),
            ),
            child: child,
          );
        },
      ),
    );
  }

  Widget _buildLyricsPreviewContainer(
    BuildContext context,
    YoutubeTrack track,
    Color accentColor,
    Color bgColor,
    double screenHeight,
  ) {
    final videoId = track.id;
    final timedLyricsAsync = ref.watch(timedLyricsProvider(videoId));
    final lyricsAsync = ref.watch(lyricsProvider(videoId));
    final positionAsync = ref.watch(playerPositionProvider);
    final position = positionAsync.value ?? Duration.zero;

    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: () {
          _openFullScreenLyrics(context, track, bgColor, accentColor);
        },
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                bgColor.withValues(alpha: 0.15),
                bgColor.withValues(alpha: 0.35),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1.0,
            ),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Apple Music-style lyrics card header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      const Text(
                        'Lyrics',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          _openFullScreenLyrics(context, track, bgColor, accentColor);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                          child: const Icon(
                            Icons.open_in_full_rounded,
                            color: Colors.white70,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: timedLyricsAsync.when(
                    data: (timedLines) {
                      if (timedLines.isEmpty) {
                        return _buildPlainLyricsPreview(lyricsAsync);
                      }

                      int activeIndex = 0;
                      for (int i = 0; i < timedLines.length; i++) {
                        if (position >= timedLines[i].time) {
                          activeIndex = i;
                        } else {
                          break;
                        }
                      }

                      // If song proceeds to a new line, force auto-scroll to snap back
                      if (activeIndex != _lastPreviewActiveLyricIndex) {
                        _isUserScrollingPreview = false;
                      }

                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _scrollToActivePreviewLyric(activeIndex, timedLines.length);
                      });

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final viewportHeight = constraints.maxHeight;
                          const itemHeight = 44.0;
                          final verticalPadding = (viewportHeight - itemHeight) / 2;

                          return NotificationListener<ScrollNotification>(
                            onNotification: (notification) {
                              if (notification is ScrollStartNotification) {
                                if (notification.dragDetails != null) {
                                  _previewLyricsFallbackTimer?.cancel();
                                  _isUserScrollingPreview = true;
                                  _lastPreviewActiveLyricIndex = -1; // reset to force scrollback
                                }
                              } else if (notification is ScrollUpdateNotification) {
                                if (notification.dragDetails != null) {
                                  _isManualScrollInProgress = true;
                                }
                              } else if (notification is ScrollEndNotification) {
                                if (_isManualScrollInProgress) {
                                  _isManualScrollInProgress = false;
                                  _previewLyricsFallbackTimer?.cancel();
                                  _previewLyricsFallbackTimer = Timer(const Duration(seconds: 3), () {
                                    if (mounted) {
                                      setState(() {
                                        _isUserScrollingPreview = false;
                                      });
                                    }
                                  });
                                }
                              }
                              return false;
                            },
                            child: ListView.builder(
                              controller: _previewLyricsScrollController,
                              physics: const BouncingScrollPhysics(),
                              padding: EdgeInsets.symmetric(horizontal: 20, vertical: verticalPadding),
                              itemCount: timedLines.length,
                              itemBuilder: (context, index) {
                                final line = timedLines[index];
                                final isActive = index == activeIndex;

                                return GestureDetector(
                                  onTap: () {
                                    ref.read(playerHandlerProvider).seek(line.time);
                                  },
                                  child: Container(
                                    constraints: BoxConstraints(minHeight: itemHeight),
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    child: Center(
                                      child: AnimatedDefaultTextStyle(
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.easeInOutCubic,
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: isActive ? 18 : 14,
                                          fontWeight: isActive ? FontWeight.w900 : FontWeight.bold,
                                          color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.35),
                                          shadows: isActive
                                              ? [
                                                  Shadow(
                                                    color: accentColor.withValues(alpha: 0.85),
                                                    blurRadius: 18,
                                                  ),
                                                ]
                                              : null,
                                        ),
                                        textAlign: TextAlign.center,
                                        child: Text(
                                          line.text,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
                    error: (_, __) => _buildPlainLyricsPreview(lyricsAsync),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlainLyricsPreview(AsyncValue<String?> lyricsAsync) {
    return lyricsAsync.when(
      data: (lyrics) {
        if (lyrics == null || lyrics.trim().isEmpty) {
          return const Center(
            child: Text(
              'Tap to fetch lyrics.',
              style: TextStyle(fontFamily: 'Inter', color: Colors.white38, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          );
        }

        final lines = lyrics.split('\n').where((l) => l.trim().isNotEmpty).take(2).toList();
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: lines.map((l) {
            final isFirst = lines.indexOf(l) == 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                l,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: isFirst ? 14 : 12,
                  fontWeight: FontWeight.bold,
                  color: isFirst ? Colors.white70 : Colors.white38,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
      error: (e, _) => const Center(child: Text('Tap to load lyrics', style: TextStyle(color: Colors.white38, fontSize: 13, fontWeight: FontWeight.bold))),
    );
  }

  // ── sliding glass bottom sheet displaying Up Next queue, lyrics, and related suggestions ──
  void _showQueueBottomSheet(BuildContext context, String? videoId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.72,
              decoration: BoxDecoration(
                color: AppColorSchemes.bgMid.withValues(alpha: 0.9),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1),
                ),
              ),
              child: DefaultTabController(
                length: 3,
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Elegant tab headers styled like YT Music
                    const TabBar(
                      tabs: [
                        Tab(text: 'UP NEXT'),
                        Tab(text: 'LYRICS'),
                        Tab(text: 'RELATED'),
                      ],
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white38,
                      indicatorColor: Colors.white,
                      indicatorSize: TabBarIndicatorSize.label,
                      dividerColor: Colors.transparent,
                      labelStyle: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildUpNextTab(context),
                          _buildLyricsTab(context, videoId),
                          _buildRelatedTab(context, videoId),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildUpNextTab(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final handler = ref.watch(playerHandlerProvider);
        final queue = handler.queueList;
        final playbackState = ref.watch(playbackStateProvider).value;
        final isPlaying = playbackState?.playing ?? false;

        if (queue.isEmpty) {
          return const Center(
            child: Text('Queue is empty', style: TextStyle(color: Colors.white38)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          itemCount: queue.length,
          itemBuilder: (context, index) {
            final qTrack = queue[index];
            final isCurrent = index == handler.currentIndex;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () {
                  if (isCurrent) {
                    if (isPlaying) {
                      handler.pause();
                    } else {
                      handler.play();
                    }
                  } else {
                    Navigator.pop(context);
                    handler.playTrack(qTrack);
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: isCurrent ? Colors.white.withValues(alpha: 0.12) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: isCurrent
                        ? Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 1.0,
                          )
                        : null,
                   ),
                   child: Row(
                     children: [
                       ClipRRect(
                         borderRadius: BorderRadius.circular(8),
                         child: qTrack.artworkUrl != null
                             ? CachedNetworkImage(
                                 imageUrl: qTrack.artworkUrl!,
                                 width: 44,
                                 height: 44,
                                 fit: BoxFit.cover,
                                 alignment: Alignment.center,
                               )
                             : Container(
                                 width: 44,
                                 height: 44,
                                 color: AppColorSchemes.surface2,
                                 child: const Icon(Icons.music_note_rounded, color: Colors.white24),
                               ),
                       ),
                       const SizedBox(width: 12),
                       Expanded(
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Text(
                               qTrack.title,
                               style: TextStyle(
                                 fontFamily: 'Inter',
                                 fontSize: 14,
                                 fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                                 color: isCurrent ? Colors.white : Colors.white.withValues(alpha: 0.85),
                               ),
                               maxLines: 1,
                               overflow: TextOverflow.ellipsis,
                             ),
                             const SizedBox(height: 2),
                             Text(
                               qTrack.artistName,
                               style: TextStyle(
                                 fontFamily: 'Inter',
                                 fontSize: 12,
                                 color: isCurrent ? Colors.white.withValues(alpha: 0.6) : Colors.white38,
                               ),
                               maxLines: 1,
                               overflow: TextOverflow.ellipsis,
                             ),
                           ],
                         ),
                       ),
                       if (isCurrent)
                         Icon(
                           isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                           color: Colors.white,
                           size: 20,
                         )
                       else
                         const Icon(Icons.play_arrow_rounded, color: Colors.white38),
                     ],
                   ),
                 ),
               ),
             );
           },
         );
       },
     );
   }

   Widget _buildLyricsTab(BuildContext context, String? videoId) {
     if (videoId == null) {
       return const Center(child: Text('No song playing', style: TextStyle(color: Colors.white38)));
     }
     return Consumer(
       builder: (context, ref, child) {
         final timedLyricsAsync = ref.watch(timedLyricsProvider(videoId));
         final lyricsAsync = ref.watch(lyricsProvider(videoId));

         return Padding(
           padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
           child: timedLyricsAsync.when(
             data: (lines) {
               if (lines.isEmpty) {
                 return _buildPlainLyricsPreview(lyricsAsync);
               }
               
               return StreamBuilder<Duration>(
                 stream: ref.watch(playerHandlerProvider).positionStream,
                 builder: (context, snapshot) {
                   final currentPos = snapshot.data ?? Duration.zero;
                   int activeIndex = -1;
                   for (int i = 0; i < lines.length; i++) {
                     if (currentPos >= lines[i].time) {
                       activeIndex = i;
                     }
                   }

                   return ListView.builder(
                     itemCount: lines.length,
                     itemBuilder: (context, index) {
                       final isCurrent = index == activeIndex;
                       return Padding(
                         padding: const EdgeInsets.symmetric(vertical: 8.0),
                         child: Text(
                           lines[index].text,
                           style: TextStyle(
                             fontFamily: 'Inter',
                             fontSize: isCurrent ? 17 : 14,
                             fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                             color: isCurrent ? Colors.white : Colors.white38,
                           ),
                           textAlign: TextAlign.center,
                         ),
                       );
                     },
                   );
                 },
               );
             },
             loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
             error: (_, __) => _buildPlainLyricsPreview(lyricsAsync),
           ),
         );
       },
     );
   }

   Widget _buildRelatedTab(BuildContext context, String? videoId) {
     if (videoId == null) {
       return const Center(child: Text('No song playing', style: TextStyle(color: Colors.white38)));
     }
     
     return Consumer(
       builder: (context, ref, child) {
         final currentTrackAsync = ref.watch(currentTrackProvider);
         final currentTrack = currentTrackAsync.value;
         if (currentTrack == null) {
           return const Center(child: Text('No track metadata available', style: TextStyle(color: Colors.white38)));
         }

         final relatedTracksAsync = ref.watch(upNextProvider(videoId));
         final query = "${currentTrack.artistName} playlist";
         final relatedPlaylistsAsync = ref.watch(relatedPlaylistsProvider(query));

         return SingleChildScrollView(
           padding: const EdgeInsets.symmetric(vertical: 16),
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               // ─── Shelf 1: You Might Also Like ───
               const Padding(
                 padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                 child: Text(
                   'You Might Also Like',
                   style: TextStyle(
                     fontFamily: 'Inter',
                     fontSize: 16,
                     fontWeight: FontWeight.bold,
                     color: Colors.white,
                   ),
                 ),
               ),
               SizedBox(
                 height: 190,
                 child: relatedTracksAsync.when(
                   data: (tracks) {
                     if (tracks.isEmpty) {
                       return const Center(
                         child: Text('No similar songs found', style: TextStyle(color: Colors.white38, fontSize: 13)),
                       );
                     }
                     return ListView.builder(
                       padding: const EdgeInsets.symmetric(horizontal: 20),
                       scrollDirection: Axis.horizontal,
                       itemCount: tracks.length.clamp(0, 15),
                       itemBuilder: (context, index) {
                         final t = tracks[index];
                         return GestureDetector(
                           onTap: () {
                             Navigator.pop(context);
                             ref.read(playerHandlerProvider).playTrack(t);
                           },
                           child: Container(
                             width: 130,
                             margin: const EdgeInsets.only(right: 16),
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 ClipRRect(
                                   borderRadius: BorderRadius.circular(12),
                                   child: CachedNetworkImage(
                                     imageUrl: t.artworkUrl ?? '',
                                     width: 130,
                                     height: 130,
                                     fit: BoxFit.cover,
                                     placeholder: (_, __) => Container(color: AppColorSchemes.surface2),
                                     errorWidget: (_, __, ___) => Container(
                                       color: AppColorSchemes.surface2,
                                       child: const Icon(Icons.music_note_rounded, color: Colors.white24),
                                     ),
                                   ),
                                 ),
                                 const SizedBox(height: 6),
                                 Text(
                                   t.title,
                                   style: const TextStyle(
                                     fontFamily: 'Inter',
                                     fontSize: 12,
                                     fontWeight: FontWeight.w600,
                                     color: Colors.white,
                                   ),
                                   maxLines: 1,
                                   overflow: TextOverflow.ellipsis,
                                 ),
                                 Text(
                                   t.artistName,
                                   style: const TextStyle(
                                     fontFamily: 'Inter',
                                     fontSize: 10.5,
                                     color: Colors.white38,
                                   ),
                                   maxLines: 1,
                                   overflow: TextOverflow.ellipsis,
                                 ),
                               ],
                             ),
                           ),
                         );
                       },
                     );
                   },
                   loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
                   error: (e, _) => Center(child: Text('Error loading suggestions: $e', style: const TextStyle(color: Colors.white38))),
                 ),
               ),
               
               const SizedBox(height: 18),
               
               // ─── Shelf 2: Cool Playlists for You ───
               const Padding(
                 padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                 child: Text(
                   'Cool Playlists for You',
                   style: TextStyle(
                     fontFamily: 'Inter',
                     fontSize: 16,
                     fontWeight: FontWeight.bold,
                     color: Colors.white,
                   ),
                 ),
               ),
               SizedBox(
                 height: 190,
                 child: relatedPlaylistsAsync.when(
                   data: (playlists) {
                     if (playlists.isEmpty) {
                       return const Center(
                         child: Text('No playlist suggestions found', style: TextStyle(color: Colors.white38, fontSize: 13)),
                       );
                     }
                     return ListView.builder(
                       padding: const EdgeInsets.symmetric(horizontal: 20),
                       scrollDirection: Axis.horizontal,
                       itemCount: playlists.length,
                       itemBuilder: (context, index) {
                         final p = playlists[index];
                         return GestureDetector(
                           onTap: () {
                             Navigator.pop(context);
                             context.push('/playlist/${p.id}');
                           },
                           child: Container(
                             width: 130,
                             margin: const EdgeInsets.only(right: 16),
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 ClipRRect(
                                   borderRadius: BorderRadius.circular(12),
                                   child: CachedNetworkImage(
                                     imageUrl: p.coverUrl ?? '',
                                     width: 130,
                                     height: 130,
                                     fit: BoxFit.cover,
                                     placeholder: (_, __) => Container(color: AppColorSchemes.surface2),
                                     errorWidget: (_, __, ___) => Container(
                                       color: AppColorSchemes.surface2,
                                       child: const Icon(Icons.playlist_play_rounded, color: Colors.white24, size: 36),
                                     ),
                                   ),
                                 ),
                                 const SizedBox(height: 6),
                                 Text(
                                   p.title,
                                   style: const TextStyle(
                                     fontFamily: 'Inter',
                                     fontSize: 12,
                                     fontWeight: FontWeight.w600,
                                     color: Colors.white,
                                   ),
                                   maxLines: 1,
                                   overflow: TextOverflow.ellipsis,
                                 ),
                                 Text(
                                   p.author ?? 'YouTube Music',
                                   style: const TextStyle(
                                     fontFamily: 'Inter',
                                     fontSize: 10.5,
                                     color: Colors.white38,
                                   ),
                                   maxLines: 1,
                                   overflow: TextOverflow.ellipsis,
                                 ),
                               ],
                             ),
                           ),
                         );
                       },
                     );
                   },
                   loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
                   error: (e, _) => Center(child: Text('Error loading playlists: $e', style: const TextStyle(color: Colors.white38))),
                 ),
               ),
               
               const SizedBox(height: 24),
             ],
           ),
         );
       },
     );
   }
}



class FullScreenLyricsPage extends ConsumerStatefulWidget {
  final Color bgColor;
  final Color accentColor;

  const FullScreenLyricsPage({
    super.key,
    required this.bgColor,
    required this.accentColor,
  });

  @override
  ConsumerState<FullScreenLyricsPage> createState() => _FullScreenLyricsPageState();
}

class _FullScreenLyricsPageState extends ConsumerState<FullScreenLyricsPage> {
  final ScrollController _lyricsScrollController = ScrollController();
  int _lastActiveLyricIndex = -1;
  bool _isUserScrolling = false;
  bool _isManualScrollInProgress = false;
  Timer? _lyricsFallbackTimer;

  @override
  void dispose() {
    _lyricsScrollController.dispose();
    _lyricsFallbackTimer?.cancel();
    super.dispose();
  }

  void _scrollToActiveLyric(int index) {
    if (_isUserScrolling) return;
    if (index == _lastActiveLyricIndex || !_lyricsScrollController.hasClients) return;
    _lastActiveLyricIndex = index;

    const double itemHeight = 60.0;
    final double targetOffset = index * itemHeight;

    _lyricsScrollController.animateTo(
      targetOffset.clamp(0.0, _lyricsScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final trackAsync = ref.watch(currentTrackProvider);
    final track = trackAsync.value;

    if (track == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
      return const SizedBox.shrink();
    }

    final videoId = track.id;
    final timedLyricsAsync = ref.watch(timedLyricsProvider(videoId));
    final lyricsAsync = ref.watch(lyricsProvider(videoId));
    final positionAsync = ref.watch(playerPositionProvider);
    final position = positionAsync.value ?? Duration.zero;

    final artworkUrl = track.artworkUrl;

    return Scaffold(
      backgroundColor: AppColorSchemes.bgBottom,
      body: Stack(
        children: [
          // ── Ambient Glassmorphic Background ──
          Positioned.fill(
            child: Container(
              color: AppColorSchemes.bgBottom,
            ),
          ),
          if (artworkUrl != null) ...[
            Positioned.fill(
              child: Opacity(
                opacity: 0.55,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 45, sigmaY: 45),
                  child: CachedNetworkImage(
                    imageUrl: artworkUrl,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          widget.bgColor.withValues(alpha: 0.35),
                          widget.bgColor.withValues(alpha: 0.70),
                          widget.bgColor.withValues(alpha: 0.90),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ] else ...[
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.35),
                      AppColorSchemes.bgBottom.withValues(alpha: 0.88),
                      AppColorSchemes.bgBottom,
                    ],
                  ),
                ),
              ),
            ),
          ],

          // ── Main Content ──
          SafeArea(
            child: Column(
              children: [
                // ── Premium Header ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 30),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              track.title,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              track.artistName,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (artworkUrl != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: artworkUrl,
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                              icon: Icon(
                                (ref.watch(playbackStateProvider).value?.playing ?? false)
                                    ? Icons.pause_circle_filled_rounded
                                    : Icons.play_circle_filled_rounded,
                                color: Colors.white,
                                size: 36,
                              ),
                              onPressed: () {
                                final handler = ref.read(playerHandlerProvider);
                                final isPlaying = ref.read(playbackStateProvider).value?.playing ?? false;
                                if (isPlaying) {
                                  handler.pause();
                                } else {
                                  handler.play();
                                }
                              },
                            ),
                          ],
                        ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),

                const Divider(color: Colors.white10, height: 1),

                // ── Lyrics Content ──
                Expanded(
                  child: timedLyricsAsync.when(
                    data: (timedLines) {
                      if (timedLines.isEmpty) {
                        return _buildPlainLyricsFull(lyricsAsync);
                      }

                      int activeIndex = 0;
                      for (int i = 0; i < timedLines.length; i++) {
                        if (position >= timedLines[i].time) {
                          activeIndex = i;
                        } else {
                          break;
                        }
                      }

                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _scrollToActiveLyric(activeIndex);
                      });

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final viewportHeight = constraints.maxHeight;
                          const itemHeight = 60.0;
                          final verticalPadding = (viewportHeight - itemHeight) / 2;

                          return NotificationListener<ScrollNotification>(
                            onNotification: (notification) {
                              if (notification is ScrollStartNotification) {
                                if (notification.dragDetails != null) {
                                  _lyricsFallbackTimer?.cancel();
                                  _isUserScrolling = true;
                                  _lastActiveLyricIndex = -1;
                                }
                              } else if (notification is ScrollUpdateNotification) {
                                if (notification.dragDetails != null) {
                                  _isManualScrollInProgress = true;
                                }
                              } else if (notification is ScrollEndNotification) {
                                if (_isManualScrollInProgress) {
                                  _isManualScrollInProgress = false;
                                  _lyricsFallbackTimer?.cancel();
                                  _lyricsFallbackTimer = Timer(const Duration(seconds: 4), () {
                                    if (mounted) {
                                      setState(() {
                                        _isUserScrolling = false;
                                      });
                                    }
                                  });
                                }
                              }
                              return false;
                            },
                            child: ListView.builder(
                              controller: _lyricsScrollController,
                              physics: const BouncingScrollPhysics(),
                              padding: EdgeInsets.symmetric(horizontal: 24, vertical: verticalPadding),
                              itemCount: timedLines.length,
                              itemBuilder: (context, index) {
                                final line = timedLines[index];
                                final isActive = index == activeIndex;

                                return GestureDetector(
                                  onTap: () {
                                    ref.read(playerHandlerProvider).seek(line.time);
                                    setState(() {
                                      _isUserScrolling = false;
                                    });
                                  },
                                  child: Container(
                                    constraints: BoxConstraints(minHeight: itemHeight),
                                    alignment: Alignment.centerLeft,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: AnimatedDefaultTextStyle(
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeInOutCubic,
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: isActive ? 24 : 18,
                                        fontWeight: isActive ? FontWeight.w900 : FontWeight.bold,
                                        color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.35),
                                        shadows: isActive
                                            ? [
                                                Shadow(
                                                  color: widget.accentColor.withValues(alpha: 0.85),
                                                  blurRadius: 18,
                                                ),
                                              ]
                                            : null,
                                      ),
                                      textAlign: TextAlign.left,
                                      child: Text(
                                        line.text,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
                    error: (_, __) => _buildPlainLyricsFull(lyricsAsync),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlainLyricsFull(AsyncValue<String?> lyricsAsync) {
    return lyricsAsync.when(
      data: (lyrics) {
        if (lyrics == null || lyrics.trim().isEmpty) {
          return const Center(
            child: Text(
              'No lyrics found for this track.',
              style: TextStyle(fontFamily: 'Inter', color: Colors.white38, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          );
        }

        final lines = lyrics.split('\n').where((l) => l.trim().isNotEmpty).toList();
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: lines.map((l) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  l,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.left,
                ),
              );
            }).toList(),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
      error: (e, _) => const Center(child: Text('Failed to load lyrics', style: TextStyle(color: Colors.white38, fontSize: 16, fontWeight: FontWeight.bold))),
    );
  }
}


