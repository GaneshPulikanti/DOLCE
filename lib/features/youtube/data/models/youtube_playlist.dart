import 'youtube_track.dart';

class YoutubePlaylist {
  final String id;
  final String title;
  final String? coverUrl;
  final String? author;
  final List<YoutubeTrack>? tracks;

  const YoutubePlaylist({
    required this.id,
    required this.title,
    this.coverUrl,
    this.author,
    this.tracks,
  });
}
