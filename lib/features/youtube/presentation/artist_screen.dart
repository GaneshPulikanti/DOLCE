import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/color_schemes.dart';
import '../../youtube/providers/youtube_providers.dart';
import '../../player/providers/player_provider.dart';

class ArtistScreen extends ConsumerWidget {
  final String artistId;

  const ArtistScreen({super.key, required this.artistId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(artistSongsProvider(artistId));

    return Scaffold(
      backgroundColor: AppColorSchemes.bgBottom,
      body: songsAsync.when(
        data: (songs) {
          if (songs.isEmpty) {
            return _buildErrorState(context, 'No songs found for this artist.');
          }

          final artistName = songs.first.artistName;
          final artistArtwork = songs.first.artworkUrl;

          return CustomScrollView(
            slivers: [
              // Beautiful banner SliverAppBar
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
                    artistName,
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
                      if (artistArtwork != null)
                        CachedNetworkImage(
                          imageUrl: artistArtwork,
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
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

              // Action buttons (Play All / Shuffle)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            ref.read(playerHandlerProvider).playTrack(songs.first);
                          },
                          icon: const Icon(Icons.play_arrow_rounded, color: Colors.black),
                          label: const Text('Play All', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
                              ref.read(playerHandlerProvider).playTrack(shuffled.first);
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

              // Top Tracks Section Title
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Top Songs',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              // Tracks List
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final track = songs[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () {
                            ref.read(playerHandlerProvider).playTrack(track);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Row(
                              children: [
                                Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    color: Colors.white38,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: track.artworkUrl != null
                                      ? CachedNetworkImage(
                                          imageUrl: track.artworkUrl!,
                                          width: 48,
                                          height: 48,
                                          fit: BoxFit.cover,
                                          alignment: Alignment.center,
                                        )
                                      : Container(
                                          width: 48,
                                          height: 48,
                                          color: AppColorSchemes.surface2,
                                          child: const Icon(Icons.music_note_rounded, color: Colors.white24),
                                        ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
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
                                      if (track.albumName != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          track.albumName!,
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 12,
                                            color: Colors.white.withValues(alpha: 0.5),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const Icon(Icons.play_arrow_rounded, color: Colors.white60),
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
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
        error: (e, _) => _buildErrorState(context, 'Could not fetch artist songs. $e'),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 28),
              onPressed: () => context.pop(),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              style: const TextStyle(fontFamily: 'Inter', color: Colors.white54, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
