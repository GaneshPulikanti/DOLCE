import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/color_schemes.dart';
import '../../youtube/data/models/youtube_track.dart';
import '../providers/local_library_provider.dart';

void showAddToPlaylistSheet(BuildContext context, WidgetRef ref, YoutubeTrack track) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColorSchemes.bgMid,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return Consumer(
        builder: (context, ref, _) {
          final library = ref.watch(localLibraryProvider);
          final playlists = library.playlists.values.toList();
          
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Add to Playlist',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Create New Playlist button
                  ListTile(
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.add_rounded, color: Colors.white),
                    ),
                    title: const Text(
                      'Create new playlist',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      showCreatePlaylistDialog(context, ref, track);
                    },
                  ),
                  const Divider(color: Colors.white10),
                  
                  // Scrollable playlists list
                  if (playlists.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'No playlists yet',
                          style: TextStyle(color: Colors.white30),
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: playlists.length,
                        itemBuilder: (context, index) {
                          final playlist = playlists[index];
                          final hasTrack = playlist.tracks.any((t) => t.id == track.id);
                          return ListTile(
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.playlist_play_rounded, color: Colors.white70),
                            ),
                            title: Text(
                              playlist.name,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '${playlist.tracks.length} tracks',
                              style: const TextStyle(color: Colors.white30, fontSize: 12),
                            ),
                            trailing: hasTrack 
                                ? const Icon(Icons.check_circle_rounded, color: Colors.greenAccent)
                                : null,
                            onTap: () {
                              ref.read(localLibraryProvider.notifier).addTrackToPlaylist(playlist.id, track);
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Added "${track.title}" to ${playlist.name}'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

void showCreatePlaylistDialog(BuildContext context, WidgetRef ref, YoutubeTrack? trackToAddTo) {
  final controller = TextEditingController();
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: AppColorSchemes.bgMid,
        title: const Text('New Playlist', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Playlist name',
            hintStyle: TextStyle(color: Colors.white30),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white30)),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final playlistId = ref.read(localLibraryProvider.notifier).createPlaylist(name);
                if (trackToAddTo != null) {
                  ref.read(localLibraryProvider.notifier).addTrackToPlaylist(playlistId, trackToAddTo);
                }
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Created playlist "$name"${trackToAddTo != null ? " and added track" : ""}'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Create', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      );
    },
  );
}
