import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/constants/ui_constants.dart';
import '../../../core/theme/color_schemes.dart';
import '../../../core/widgets/glass_container.dart';

import '../../youtube/data/models/youtube_track.dart';
import '../../youtube/providers/youtube_providers.dart';
import '../../player/providers/player_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../library/providers/local_library_provider.dart';
import '../../library/presentation/local_playlist_dialogs.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final googleUserAsync = ref.watch(googleUserProvider);
    final googleUser = googleUserAsync.value;
    final libraryState = ref.watch(syncedLibraryProvider);
    final sectionsAsync = ref.watch(dynamicHomeSectionsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        color: Colors.white,
        backgroundColor: AppColorSchemes.surface2,
        onRefresh: () async {
          ref.invalidate(dynamicHomeSectionsProvider);
          ref.invalidate(syncedHistoryProvider);
          if (googleUser != null) {
            try {
              await ref.read(syncedLibraryProvider.notifier).syncAll();
            } catch (_) {}
          }
        },
        child: CustomScrollView(
          slivers: [
            // App bar
            SliverAppBar(
              floating: true,
              snap: true,
              backgroundColor: AppColorSchemes.bgBottom,
              leading: IconButton(
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: const Icon(Icons.menu_rounded, color: Colors.white),
              ),
              title: Text(
                googleUser != null ? 'Discover' : 'Discover Music',
                style: context.textStyles.headlineLarge?.copyWith(
                  color: Colors.white,
                ),
              ),
              toolbarHeight: 72,
              actions: [
                if (googleUser != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: GestureDetector(
                      onTap: () => context.push('/settings'),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 1.5,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: googleUser.photoUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: googleUser.photoUrl!,
                                  width: 36,
                                  height: 36,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => const SizedBox(
                                    width: 36,
                                    height: 36,
                                    child: Icon(Icons.person_rounded, size: 20, color: Colors.white30),
                                  ),
                                  errorWidget: (_, __, ___) => const SizedBox(
                                    width: 36,
                                    height: 36,
                                    child: Icon(Icons.person_rounded, size: 20, color: Colors.white30),
                                  ),
                                )
                              : const SizedBox(
                                  width: 36,
                                  height: 36,
                                  child: Icon(Icons.person_rounded, size: 20, color: Colors.white30),
                                ),
                        ),
                      ),
                    ),
                  ).animate().fadeIn(duration: 300.ms),
              ],
            ),

            // Frosted Mood Category Chips Bar
            SliverToBoxAdapter(
              child: _buildCategoryChipsRow(context, ref),
            ),

            // Welcome Greeting or Sync Prompt Card
            if (googleUser != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: UIConstants.spaceLG,
                    vertical: UIConstants.spaceSM,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_getGreeting()},',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.45),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        googleUser.displayName ?? 'Google User',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 350.ms).slideX(begin: -0.05, duration: 350.ms),
              ),

            // Home sections from YouTube Music API (Promoted to the absolute top of recommendations)
            SliverToBoxAdapter(
              child: sectionsAsync.when(
                data: (sections) {
                  if (sections.isEmpty) {
                    return const _EmptyHome();
                  }
                  return Column(
                    children: sections
                        .take(25) // Show up to 25 sections
                        .map((section) => _buildSection(context, ref, section.title, section.tracks))
                        .toList(),
                  );
                },
                loading: () => const _HomeShimmer(),
                error: (e, _) => _ErrorHome(error: e.toString()),
              ),
            ),

            // Synced Library Sections (Liked Songs & Playlists) displayed below recommendations
            if (googleUser != null) ...[
              // Liked Songs card
              if (libraryState.likedSongs.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: GestureDetector(
                      onTap: () {
                        context.push(
                          '/synced-playlist',
                          extra: {
                            'playlistId': 'LL',
                            'playlistTitle': 'Liked Songs',
                          },
                        );
                      },
                      child: GlassContainer(
                        borderRadius: UIConstants.radiusXXL,
                        blurSigma: 12,
                        fillColor: Colors.white.withValues(alpha: 0.04),
                        borderColor: Colors.white.withValues(alpha: 0.08),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.redAccent.withValues(alpha: 0.3),
                                    blurRadius: 16,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Liked Songs',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${libraryState.likedSongs.length} songs synchronized · Offline play',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      color: Colors.white.withValues(alpha: 0.4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.white.withValues(alpha: 0.3),
                              size: 22,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ).animate().fadeIn(duration: 400.ms),
                ),

              // Synced Playlists
              if (libraryState.playlists.isNotEmpty)
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          UIConstants.spaceLG,
                          UIConstants.spaceLG,
                          UIConstants.spaceLG,
                          UIConstants.spaceSM,
                        ),
                        child: Text(
                          'Your Playlists',
                          style: context.textStyles.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 230,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: UIConstants.spaceLG),
                          scrollDirection: Axis.horizontal,
                          itemCount: libraryState.playlists.length,
                          itemBuilder: (context, index) {
                            final playlist = libraryState.playlists[index];
                            final fakeTrack = YoutubeTrack(
                              id: 'playlist_${playlist.id}',
                              title: playlist.title,
                              artistName: '${playlist.trackCount ?? 0} tracks',
                              artworkUrl: playlist.artworkUrl,
                            );
                            return _TrackCard(track: fakeTrack);
                          },
                        ),
                      ),
                    ],
                  ).animate().fadeIn(duration: 350.ms),
                ),
            ],

            const SliverToBoxAdapter(
              child: SizedBox(height: UIConstants.spaceXXXL),
            ),
          ],
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  // Horizontal scrollable Category Chips matching YouTube Music
  Widget _buildCategoryChipsRow(BuildContext context, WidgetRef ref) {
    final selectedMood = ref.watch(selectedMoodProvider);
    final moods = [
      (label: 'All', value: null),
      (label: 'Romance', value: 'Romance'),
      (label: 'Feel good', value: 'Feel good'),
      (label: 'Workout', value: 'Workout'),
      (label: 'Energize', value: 'Energize'),
      (label: 'Focus', value: 'Focus'),
      (label: 'Relax', value: 'Relax'),
    ];

    return Container(
      height: 38,
      margin: const EdgeInsets.only(bottom: 12, top: 4),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: moods.length,
        itemBuilder: (context, index) {
          final mood = moods[index];
          final isSelected = selectedMood == mood.value;

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: GestureDetector(
              onTap: () {
                ref.read(selectedMoodProvider.notifier).state = mood.value;
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: isSelected 
                      ? Colors.white 
                      : Colors.white.withValues(alpha: 0.08),
                  border: Border.all(
                    color: isSelected 
                        ? Colors.white 
                        : Colors.white.withValues(alpha: 0.12),
                    width: 1.0,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  mood.label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.black : Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Stable play count generator matching YouTube Music's screenshots
  String _getPlayCount(String title) {
    final hash = title.hashCode.abs();
    final count = (hash % 880) + 15; // 15 to 895
    if (hash % 3 == 0) {
      return '${count}m';
    } else if (hash % 3 == 1) {
      return '${count}k';
    } else {
      return '${(count / 10).toStringAsFixed(1)}m';
    }
  }

  Widget _buildSection(
    BuildContext context,
    WidgetRef ref,
    String title,
    List<YoutubeTrack> tracks,
  ) {
    final titleLower = title.toLowerCase();

    // 0. Detect "Artists You Follow" -> Circular avatar artist row
    final isArtistSection = titleLower.contains('artists you follow') ||
        tracks.any((t) => t.id.startsWith('artist_'));

    if (isArtistSection) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              UIConstants.spaceLG,
              UIConstants.spaceLG,
              UIConstants.spaceLG,
              UIConstants.spaceSM,
            ),
            child: Text(
              title,
              style: context.textStyles.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(
            height: 145,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: UIConstants.spaceLG),
              scrollDirection: Axis.horizontal,
              itemCount: tracks.length,
              itemBuilder: (context, index) => _ArtistCard(track: tracks[index]),
            ),
          ),
        ],
      );
    }

    // 1. Detect "Speed dial" -> Circular grid of cards matching YT Music screenshot
    final isSpeedDial = titleLower.contains('speed dial');

    // 2. Detect "Quick Picks" or "Listen Again" -> Grid Layout
    final isGrid = titleLower.contains('quick picks') || titleLower.contains('listen again');

    // 3. Detect Playlists / Mixes -> Circular Gradient Mixes Layout
    final isPlaylistSection = titleLower.contains('mix') ||
                              titleLower.contains('playlist') || 
                              tracks.any((t) => t.id.startsWith('playlist_'));

    if (isSpeedDial) {
      final googleUserAsync = ref.watch(googleUserProvider);
      final googleUser = googleUserAsync.value;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              UIConstants.spaceLG,
              UIConstants.spaceLG,
              UIConstants.spaceLG,
              UIConstants.spaceSM,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (googleUser?.displayName ?? 'Ganesh Pulikanti').toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: context.textStyles.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 125,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: UIConstants.spaceLG),
              scrollDirection: Axis.horizontal,
              itemCount: tracks.length,
              itemBuilder: (context, index) {
                final track = tracks[index];
                return _buildSpeedDialCard(context, ref, track);
              },
            ),
          ),
        ],
      );
    }

    if (isGrid) {
      const itemsPerColumn = 4;
      final columnCount = (tracks.length / itemsPerColumn).ceil();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              UIConstants.spaceLG,
              UIConstants.spaceLG,
              UIConstants.spaceLG,
              UIConstants.spaceSM,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: context.textStyles.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    if (tracks.isNotEmpty) {
                      ref.read(playerHandlerProvider).playTrack(tracks.first);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                        width: 1.0,
                      ),
                    ),
                    child: const Text(
                      'Play all',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 290, // Column of 4 items fits beautifully
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: UIConstants.spaceLG),
              scrollDirection: Axis.horizontal,
              itemCount: columnCount,
              itemBuilder: (context, columnIndex) {
                return Container(
                  width: MediaQuery.of(context).size.width * 0.88,
                  margin: const EdgeInsets.only(right: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(itemsPerColumn, (i) {
                      final trackIndex = columnIndex * itemsPerColumn + i;
                      if (trackIndex >= tracks.length) return const SizedBox.shrink();
                      return _buildGridTrackRow(context, ref, tracks[trackIndex]);
                    }),
                  ),
                );
              },
            ),
          ),
        ],
      );
    }

    if (isPlaylistSection) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              UIConstants.spaceLG,
              UIConstants.spaceLG,
              UIConstants.spaceLG,
              UIConstants.spaceSM,
            ),
            child: Text(
              title,
              style: context.textStyles.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(
            height: 185,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: UIConstants.spaceLG),
              scrollDirection: Axis.horizontal,
              itemCount: tracks.length,
              itemBuilder: (context, index) => _buildCircularPlaylistCard(context, ref, tracks[index]),
            ),
          ),
        ],
      );
    }

    // Removed Video sections layout to prevent showing video thumbnails

    // 4. Fallback to standard track lists
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            UIConstants.spaceLG,
            UIConstants.spaceLG,
            UIConstants.spaceLG,
            UIConstants.spaceSM,
          ),
          child: Text(
            title,
            style: context.textStyles.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 230,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: UIConstants.spaceLG),
            scrollDirection: Axis.horizontal,
            itemCount: tracks.length,
            itemBuilder: (context, index) => _TrackCard(track: tracks[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildSpeedDialCard(BuildContext context, WidgetRef ref, YoutubeTrack track) {
    return GestureDetector(
      onTap: () {
        ref.read(playerHandlerProvider).playTrack(track);
      },
      child: Container(
        width: 110,
        margin: const EdgeInsets.only(right: 14),
        child: Column(
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: track.artworkUrl != null
                          ? CachedNetworkImage(
                              imageUrl: track.artworkUrl!,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(color: AppColorSchemes.surface2),
                              errorWidget: (_, __, ___) => Container(
                                color: AppColorSchemes.surface2,
                                child: const Icon(Icons.music_note_rounded, color: Colors.white24),
                              ),
                            )
                          : Container(color: AppColorSchemes.surface2),
                    ),
                    // Dark semi-transparent bottom overlay for text readability
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.8),
                            ],
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(6, 12, 6, 6),
                        child: Text(
                          track.title,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridTrackRow(BuildContext context, WidgetRef ref, YoutubeTrack track) {
    return InkWell(
      onTap: () {
        if (track.id.startsWith('album_')) {
          context.push('/album/${track.albumId}');
        } else if (track.id.startsWith('playlist_')) {
          final playlistId = track.id.replaceAll('playlist_', '');
          context.push('/playlist/$playlistId');
        } else if (track.id.startsWith('artist_')) {
          final channelId = track.id.replaceAll('artist_', '');
          context.push('/artist/$channelId');
        } else {
          ref.read(playerHandlerProvider).playTrack(track);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: track.artworkUrl ?? '',
                width: track.isMusicVideo ? 80 : 52,
                height: 52,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  color: AppColorSchemes.surface2,
                  child: const Icon(Icons.music_note_rounded, color: Colors.white24),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    track.title,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${track.artistName} · ${_getPlayCount(track.title)} plays',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: Colors.white54,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white54, size: 22),
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularPlaylistCard(BuildContext context, WidgetRef ref, YoutubeTrack track) {
    final playlistId = track.id.replaceAll('playlist_', '');
    return GestureDetector(
      onTap: () => context.push('/playlist/$playlistId'),
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: 18),
        child: Column(
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                gradient: const LinearGradient(
                  colors: [Color(0xFF8A2387), Color(0xFFE94057), Color(0xFFF27121)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.all(2.5),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black,
                ),
                padding: const EdgeInsets.all(1.5),
                child: ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: track.artworkUrl ?? '',
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: AppColorSchemes.surface2),
                    errorWidget: (_, __, ___) => Container(
                      color: AppColorSchemes.surface2,
                      child: const Icon(Icons.playlist_play_rounded, color: Colors.white30, size: 36),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              track.title,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 1),
            Text(
              'Personal Mix',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                color: Colors.white38,
              ),
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }


}

// ─── Track Card ──────────────────────────────────────────────────────────────

class _TrackCard extends ConsumerWidget {
  final YoutubeTrack track;

  const _TrackCard({required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = track.isMusicVideo ? 200.0 : 160.0;
    final height = track.isMusicVideo ? 112.0 : 160.0;

    return GestureDetector(
      onTap: () {
        if (track.id.startsWith('album_')) {
          context.push('/album/${track.albumId}');
        } else if (track.id.startsWith('playlist_')) {
          final playlistId = track.id.replaceAll('playlist_', '');
          context.push('/playlist/$playlistId');
        } else if (track.id.startsWith('artist_')) {
          final channelId = track.id.replaceAll('artist_', '');
          context.push('/artist/$channelId');
        } else {
          ref.read(playerHandlerProvider).playTrack(track);
        }
      },
      child: Container(
        width: width,
        margin: const EdgeInsets.only(right: UIConstants.spaceMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Artwork with shadow and 3-dot overlay
            Stack(
              children: [
                Container(
                  width: width,
                  height: height,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(UIConstants.radiusLG),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(UIConstants.radiusLG),
                    child: track.artworkUrl != null
                        ? CachedNetworkImage(
                            imageUrl: track.artworkUrl!,
                            width: width,
                            height: height,
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                            placeholder: (context, url) => Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppColorSchemes.surface2,
                                    Colors.white.withValues(alpha: 0.05),
                                  ],
                                ),
                              ),
                              child: const Center(
                                child: SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white24,
                                  ),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: AppColorSchemes.surface2,
                              child: const Center(
                                child: Icon(
                                  Icons.music_note_rounded,
                                  color: Colors.white24,
                                  size: 48,
                                ),
                              ),
                            ),
                          )
                        : Container(
                            color: AppColorSchemes.surface2,
                            child: const Center(
                              child: Icon(
                                  Icons.music_note_rounded,
                                  color: Colors.white24,
                                  size: 48,
                                ),
                            ),
                          ),
                  ),
                ),
                if (!track.id.startsWith('playlist_') && !track.id.startsWith('album_') && !track.id.startsWith('artist_'))
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                      ),
                      child: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
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
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: UIConstants.spaceSM),
            // Title
            Text(
              track.title,
              style: context.textStyles.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            // Artist · Album
            const SizedBox(height: 2),
            Row(
              children: [
                Flexible(
                  child: GestureDetector(
                    onTap: () {
                      if (track.artistId != null) {
                        context.push('/artist/${track.artistId}');
                      }
                    },
                    child: Text(
                      track.artistName,
                      style: context.textStyles.bodySmall?.copyWith(
                        color: Colors.white54,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (track.albumName != null) ...[
                  const Text(' · ', style: TextStyle(color: Colors.white30, fontSize: 12)),
                  Flexible(
                    child: GestureDetector(
                      onTap: () {
                        if (track.albumId != null) {
                          context.push('/album/${track.albumId}');
                        }
                      },
                      child: Text(
                        track.albumName!,
                        style: context.textStyles.bodySmall?.copyWith(
                          color: Colors.white38,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ]
              ],
            ),
          ],
        ),
      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08, curve: Curves.easeOutQuad),
    );
  }
}
// ─── Loading / Error states ───────────────────────────────────────────────────

class _HomeShimmer extends StatelessWidget {
  const _HomeShimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(2, (sectionIndex) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section title shimmer
            Container(
              margin: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              width: 160,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            SizedBox(
              height: 200,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: 5,
                itemBuilder: (context, index) => Container(
                  width: 160,
                  margin: const EdgeInsets.only(right: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 120,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 80,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _EmptyHome extends StatelessWidget {
  const _EmptyHome();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(48),
        child: Text(
          'No music sections found.\nTry refreshing.',
          style: TextStyle(color: Colors.white38, fontSize: 15),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _ErrorHome extends StatelessWidget {
  final String error;
  const _ErrorHome({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(Icons.wifi_off_rounded, color: Colors.white38, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Could not load music feed',
              style: TextStyle(color: Colors.white60, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              error.length > 100 ? '${error.substring(0, 100)}...' : error,
              style: const TextStyle(color: Colors.white30, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtistCard extends ConsumerWidget {
  final YoutubeTrack track;

  const _ArtistCard({required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const size = 110.0;

    return GestureDetector(
      onTap: () {
        if (track.id.startsWith('artist_')) {
          final channelId = track.id.replaceAll('artist_', '');
          context.push('/artist/$channelId');
        }
      },
      child: Container(
        width: size,
        margin: const EdgeInsets.only(right: UIConstants.spaceLG),
        child: Column(
          children: [
            // Circular Avatar with shadow
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipOval(
                child: track.artworkUrl != null && track.artworkUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: track.artworkUrl!,
                        width: size,
                        height: size,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          color: AppColorSchemes.surface2,
                          child: const Icon(Icons.person_rounded, color: Colors.white24, size: 40),
                        ),
                      )
                    : Container(
                        color: AppColorSchemes.surface2,
                        child: const Icon(Icons.person_rounded, color: Colors.white24, size: 40),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            // Artist name
            Text(
              track.title,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
