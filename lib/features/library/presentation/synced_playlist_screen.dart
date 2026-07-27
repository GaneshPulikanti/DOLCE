import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/color_schemes.dart';
import '../../player/providers/player_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../youtube/data/models/youtube_track.dart';

class SyncedPlaylistScreen extends ConsumerWidget {
  final String playlistId;
  final String playlistTitle;
  final String? artworkUrl;

  const SyncedPlaylistScreen({
    super.key,
    required this.playlistId,
    required this.playlistTitle,
    this.artworkUrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryState = ref.watch(syncedLibraryProvider);
    
    final List<YoutubeTrack> songs = playlistId == 'LL'
        ? libraryState.likedSongs
        : (libraryState.playlistTracks[playlistId] ?? const []);

    return Scaffold(
      backgroundColor: AppColorSchemes.bgBottom,
      body: songs.isEmpty
          ? _buildEmptyState(context)
          : CustomScrollView(
              slivers: [
                // Banner SliverAppBar
                SliverAppBar(
                  expandedHeight: 280,
                  pinned: true,
                  backgroundColor: AppColorSchemes.bgBottom,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    onPressed: () => context.pop(),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(
                      playlistTitle,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(color: Colors.black54, blurRadius: 10),
                        ],
                      ),
                    ),
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (artworkUrl != null)
                          CachedNetworkImage(
                            imageUrl: artworkUrl!,
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                          )
                        else if (playlistId == 'LL')
                          Container(
                            color: Colors.redAccent.withValues(alpha: 0.15),
                            child: const Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 80),
                          )
                        else
                          Container(color: AppColorSchemes.surface2),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                AppColorSchemes.bgBottom.withValues(alpha: 0.5),
                                AppColorSchemes.bgBottom,
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Playlist Meta
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Row(
                      children: [
                        Icon(
                          playlistId == 'LL' ? Icons.favorite_rounded : Icons.playlist_play_rounded,
                          color: playlistId == 'LL' ? Colors.redAccent : Colors.white60,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          playlistId == 'LL'
                              ? 'Liked Songs · ${songs.length} tracks'
                              : 'Playlist · ${songs.length} songs',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Action buttons
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              ref.read(playerHandlerProvider).playQueue(songs, initialIndex: 0);
                            },
                            icon: const Icon(Icons.play_arrow_rounded, color: Colors.black),
                            label: const Text('Play', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              final shuffled = [...songs]..shuffle();
                              if (shuffled.isNotEmpty) {
                                ref.read(playerHandlerProvider).playQueue(shuffled, initialIndex: 0);
                              }
                            },
                            icon: const Icon(Icons.shuffle_rounded, color: Colors.white),
                            label: const Text('Shuffle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white30),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Playlist Songs List
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final track = songs[index];
                        final currentTrack = ref.watch(currentTrackProvider).value;
                        final playbackState = ref.watch(playbackStateProvider).value;
                        final isPlaying = playbackState?.playing ?? false;
                        final isCurrent = currentTrack?.id == track.id;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            onTap: () {
                              final handler = ref.read(playerHandlerProvider);
                              if (isCurrent) {
                                if (isPlaying) {
                                  handler.pause();
                                } else {
                                  handler.play();
                                }
                              } else {
                                handler.playQueue(songs, initialIndex: index);
                              }
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isCurrent ? Colors.white.withValues(alpha: 0.12) : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                                border: isCurrent
                                    ? Border.all(
                                        color: Colors.white.withValues(alpha: 0.15),
                                        width: 1.0,
                                      )
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      color: isCurrent ? Colors.white : Colors.white38,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          track.title,
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 14,
                                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                                            color: isCurrent ? Colors.white : Colors.white,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          track.artistName,
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 12,
                                            color: isCurrent
                                                ? Colors.white.withValues(alpha: 0.8)
                                                : Colors.white.withValues(alpha: 0.5),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    isCurrent && isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    color: isCurrent ? Colors.white : Colors.white60,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: songs.length,
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColorSchemes.bgBottom,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Text(playlistTitle),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.music_note_rounded, color: Colors.white24, size: 64),
              SizedBox(height: 16),
              Text(
                'No tracks synced or available in this playlist yet.',
                style: TextStyle(fontFamily: 'Inter', color: Colors.white54, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
