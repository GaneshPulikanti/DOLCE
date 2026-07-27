import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/color_schemes.dart';
import '../../player/providers/player_provider.dart';
import '../providers/local_library_provider.dart';
import '../../youtube/data/models/youtube_track.dart';

class LocalPlaylistScreen extends ConsumerWidget {
  final String playlistId;

  const LocalPlaylistScreen({
    super.key,
    required this.playlistId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryState = ref.watch(localLibraryProvider);
    final isFav = playlistId == 'favorites';
    final isDownloads = playlistId == 'downloads';
    
    final playlist = (isFav || isDownloads) 
        ? null 
        : libraryState.playlists[playlistId];
        
    final playlistTitle = isFav 
        ? 'Favorites' 
        : (isDownloads ? 'Downloads' : (playlist?.name ?? 'Playlist'));
        
    final List<YoutubeTrack> songs = isFav 
        ? libraryState.favorites 
        : (isDownloads ? libraryState.downloads : (playlist?.tracks ?? const []));

    final String? artworkUrl = songs.isNotEmpty ? songs.first.artworkUrl : null;

    return Scaffold(
      backgroundColor: AppColorSchemes.bgBottom,
      body: songs.isEmpty
          ? _buildEmptyState(context, ref, playlistTitle)
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
                  actions: [
                    if (!isFav && playlist != null)
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: AppColorSchemes.bgMid,
                              title: const Text('Delete Playlist', style: TextStyle(color: Colors.white)),
                              content: Text('Are you sure you want to delete "${playlist.name}"?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel', style: TextStyle(color: Colors.white30)),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            ref.read(localLibraryProvider.notifier).deletePlaylist(playlistId);
                            context.pop();
                          }
                        },
                      ),
                  ],
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
                            imageUrl: artworkUrl,
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                          )
                        else if (isFav)
                          Container(
                            color: Colors.redAccent.withValues(alpha: 0.15),
                            child: const Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 80),
                          )
                        else if (isDownloads)
                          Container(
                            color: Colors.blueAccent.withValues(alpha: 0.15),
                            child: const Icon(Icons.download_for_offline_rounded, color: Colors.blueAccent, size: 80),
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
                          isFav ? Icons.favorite_rounded : Icons.playlist_play_rounded,
                          color: isFav ? Colors.redAccent : Colors.white60,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isFav
                              ? 'Favorites · ${songs.length} tracks'
                              : 'Local Playlist · ${songs.length} songs',
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
                        if (!isDownloads && songs.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.download_for_offline_rounded, color: Colors.white70),
                            iconSize: 32,
                            onPressed: () async {
                              final notifier = ref.read(localLibraryProvider.notifier);
                              for (final song in songs) {
                                await notifier.addDownload(song);
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('All songs downloaded to local storage!'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ],
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
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: SizedBox(
                                      width: 48,
                                      height: 48,
                                      child: track.artworkUrl != null
                                          ? CachedNetworkImage(
                                              imageUrl: track.artworkUrl!,
                                              fit: BoxFit.cover,
                                              errorWidget: (_, __, ___) => Container(
                                                color: AppColorSchemes.surface2,
                                                child: const Icon(Icons.music_note_rounded, color: Colors.white24),
                                              ),
                                            )
                                          : Container(
                                              color: AppColorSchemes.surface2,
                                              child: const Icon(Icons.music_note_rounded, color: Colors.white24),
                                            ),
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
                                            color: Colors.white.withValues(alpha: 0.4),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.white54, size: 20),
                                    onPressed: () {
                                      if (isFav) {
                                        ref.read(localLibraryProvider.notifier).toggleFavorite(track);
                                      } else if (isDownloads) {
                                        ref.read(localLibraryProvider.notifier).removeDownload(track.id);
                                      } else {
                                        ref.read(localLibraryProvider.notifier).removeTrackFromPlaylist(playlistId, track.id);
                                      }
                                    },
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
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref, String title) {
    final isFav = playlistId == 'favorites';
    return Scaffold(
      backgroundColor: AppColorSchemes.bgBottom,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (!isFav)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              onPressed: () {
                ref.read(localLibraryProvider.notifier).deletePlaylist(playlistId);
                context.pop();
              },
            ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
                child: Icon(
                  isFav ? Icons.favorite_border_rounded : Icons.playlist_add_rounded,
                  color: Colors.white38,
                  size: 36,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'This playlist has no songs yet.\nSearch and add songs to play.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: Colors.white38,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
