import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/youtube_track.dart';
import '../models/youtube_playlist.dart';

class YoutubeRepository {
  final YoutubeExplode yt;

  YoutubeRepository(this.yt);

  Future<List<YoutubeTrack>> searchTracks(String query) async {
    try {
      final results = await yt.search.search(query, filter: TypeFilters.video);
      return results
          .whereType<Video>()
          .map((v) => _mapVideoToTrack(v))
          .toList();
    } catch (e) {
      // youtube_explode_dart sometimes throws FormatException when parsing livestreams ("Streamed 2 days ago")
      print('Search exception: $e');
      try {
        final results = await yt.search.getVideos(query);
        return results.whereType<Video>().map((v) => _mapVideoToTrack(v)).toList();
      } catch (fallbackError) {
        print('Fallback search exception: $fallbackError');
        return []; // Return empty list instead of crashing the UI
      }
    }
  }

  Future<YoutubePlaylist> getPlaylist(String playlistId) async {
    final playlist = await yt.playlists.get(playlistId);
    final videos = await yt.playlists.getVideos(playlistId).take(50).toList();

    return YoutubePlaylist(
      id: playlist.id.value,
      title: playlist.title,
      author: playlist.author,
      coverUrl: playlist.thumbnails.highResUrl,
      tracks: videos.map((v) => _mapVideoToTrack(v)).toList(),
    );
  }
  
  Future<List<YoutubeTrack>> getRelatedTracks(String videoId) async {
    final video = await yt.videos.get(videoId);
    final related = await yt.videos.getRelatedVideos(video);
    if (related == null) return [];
    return related.whereType<Video>().map((r) => _mapVideoToTrack(r)).toList();
  }

  YoutubeTrack _mapVideoToTrack(Video video) {
    return YoutubeTrack(
      id: video.id.value,
      title: video.title,
      artistName: video.author,
      artworkUrl: video.thumbnails.highResUrl,
      duration: video.duration,
    );
  }
}
