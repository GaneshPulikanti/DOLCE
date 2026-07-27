import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/youtube/v3.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import '../../../youtube/data/models/youtube_track.dart';
import '../models/youtube_playlist.dart';
import '../models/youtube_artist_channel.dart';

class YoutubeSyncService {
  final GoogleSignIn _googleSignIn;

  YoutubeSyncService(this._googleSignIn);

  Future<YouTubeApi?> _getYouTubeApi() async {
    final client = await _googleSignIn.authenticatedClient();
    if (client == null) return null;
    return YouTubeApi(client);
  }

  // ─── Playlists ─────────────────────────────────────────────────────────────

  /// Fetches standard playlists created by the user on YouTube/YouTube Music.
  Future<List<YoutubePlaylist>> fetchMyPlaylists() async {
    final youtube = await _getYouTubeApi();
    if (youtube == null) throw Exception('User is not authenticated');

    var playlists = <YoutubePlaylist>[];
    String? nextPageToken;

    try {
      do {
        final res = await youtube.playlists.list(
          ['snippet', 'contentDetails'],
          mine: true,
          maxResults: 50,
          pageToken: nextPageToken,
        );

        nextPageToken = res.nextPageToken;

        if (res.items != null) {
          for (final item in res.items!) {
            final id = item.id;
            final title = item.snippet?.title;
            if (id != null && title != null) {
              playlists.add(YoutubePlaylist(
                id: id,
                title: title,
                description: item.snippet?.description,
                artworkUrl: item.snippet?.thumbnails?.high?.url ??
                    item.snippet?.thumbnails?.medium?.url ??
                    item.snippet?.thumbnails?.default_?.url,
                trackCount: item.contentDetails?.itemCount,
              ));
            }
          }
        }
      } while (nextPageToken != null);
    } catch (e) {
      print('🔴 [YoutubeSyncService] Error fetching playlists: $e');
      rethrow;
    }

    return playlists;
  }

  // ─── Playlist Items ────────────────────────────────────────────────────────

  /// Fetches all songs (tracks) inside a playlist.
  /// [maxItems] — optional hard cap on items fetched (null = no limit).
  Future<List<YoutubeTrack>> fetchPlaylistItems(
    String playlistId, {
    int? maxItems,
  }) async {
    final youtube = await _getYouTubeApi();
    if (youtube == null) throw Exception('User is not authenticated');

    var tracks = <YoutubeTrack>[];
    String? nextPageToken;

    try {
      do {
        // Respect maxItems: stop fetching once we've reached the cap
        if (maxItems != null && tracks.length >= maxItems) break;

        final res = await youtube.playlistItems.list(
          ['snippet', 'contentDetails'],
          playlistId: playlistId,
          maxResults: 50,
          pageToken: nextPageToken,
        );

        nextPageToken = res.nextPageToken;

        if (res.items != null) {
          for (final item in res.items!) {
            if (maxItems != null && tracks.length >= maxItems) break;

            final videoId = item.contentDetails?.videoId;
            final title = item.snippet?.title;
            // Standard YouTube playlists contain videos that might be deleted or private
            if (videoId != null &&
                title != null &&
                title != 'Private video' &&
                title != 'Deleted video') {
              final artist = item.snippet?.videoOwnerChannelTitle ??
                  item.snippet?.channelTitle ??
                  'Unknown Artist';

              tracks.add(YoutubeTrack(
                id: videoId,
                title: title,
                artistName: artist.replaceAll(' - Topic', ''),
                artworkUrl: item.snippet?.thumbnails?.high?.url ??
                    item.snippet?.thumbnails?.medium?.url ??
                    item.snippet?.thumbnails?.default_?.url,
                duration:
                    null, // YouTube Data API playlistItems doesn't return duration directly
              ));
            }
          }
        }
      } while (nextPageToken != null);
    } catch (e) {
      print(
          '🔴 [YoutubeSyncService] Error fetching items for playlist $playlistId: $e');
      rethrow;
    }

    return tracks;
  }

  // ─── Liked Music ──────────────────────────────────────────────────────────

  /// Fetches the user's Liked Music.
  ///
  /// Tries the special YouTube Music 'LM' playlist first (music-only).
  /// Falls back to the general YouTube 'LL' (Liked Videos) playlist,
  /// capped at the most recent [maxItems] videos (default 500), then
  /// filters to music-only using [filterMusicOnly].
  Future<List<YoutubeTrack>> fetchLikedMusic({int maxItems = 500}) async {
    try {
      print(
          '🔄 [YoutubeSyncService] Syncing Liked Music from special LM playlist (cap: $maxItems)...');
      final tracks = await fetchPlaylistItems('LM', maxItems: maxItems);
      print(
          '🟢 [YoutubeSyncService] Successfully synced ${tracks.length} tracks from LM');
      return tracks;
    } catch (e) {
      print(
          '⚠️ [YoutubeSyncService] LM playlist sync failed ($e). Falling back to general YouTube LL playlist...');
      final rawTracks = await fetchPlaylistItems('LL', maxItems: maxItems);
      print(
          '🔍 [YoutubeSyncService] Filtering ${rawTracks.length} LL tracks for music category...');
      final filteredTracks = await filterMusicOnly(rawTracks);
      print(
          '🟢 [YoutubeSyncService] Successfully filtered down to ${filteredTracks.length} music tracks');
      return filteredTracks;
    }
  }

  // ─── Subscriptions ────────────────────────────────────────────────────────

  /// Fetches all channels the authenticated user is subscribed to.
  ///
  /// Returns every subscription as a [YoutubeArtistChannel] with
  /// [isMusicArtist] = false and empty [topicCategories].
  /// Call [enrichWithTopicDetails] afterward to classify music artists.
  Future<List<YoutubeArtistChannel>> fetchSubscribedChannels() async {
    final youtube = await _getYouTubeApi();
    if (youtube == null) throw Exception('User is not authenticated');

    final channels = <YoutubeArtistChannel>[];
    String? nextPageToken;

    try {
      do {
        final res = await youtube.subscriptions.list(
          ['snippet'],
          mine: true,
          maxResults: 50,
          pageToken: nextPageToken,
        );

        nextPageToken = res.nextPageToken;

        if (res.items != null) {
          for (final item in res.items!) {
            final channelId = item.snippet?.resourceId?.channelId;
            final title = item.snippet?.title;
            if (channelId == null || title == null) continue;

            channels.add(YoutubeArtistChannel(
              channelId: channelId,
              name: title,
              artworkUrl: item.snippet?.thumbnails?.high?.url ??
                  item.snippet?.thumbnails?.medium?.url ??
                  item.snippet?.thumbnails?.default_?.url,
            ));
          }
        }
      } while (nextPageToken != null);
    } catch (e) {
      print(
          '🔴 [YoutubeSyncService] Error fetching subscribed channels: $e');
      rethrow;
    }

    print(
        '🟢 [YoutubeSyncService] Fetched ${channels.length} subscribed channels');
    return channels;
  }

  /// Enriches a list of [YoutubeArtistChannel] with topic category data
  /// from the YouTube Data API `channels.list` endpoint.
  ///
  /// Sets [isMusicArtist] = true when any of these heuristics match:
  /// - `topicDetails.topicCategories` contains a URL with `/Music`
  /// - Channel title ends with ` - Topic`
  /// - Channel title contains `Vevo` or `VEVO`
  Future<List<YoutubeArtistChannel>> enrichWithTopicDetails(
    List<YoutubeArtistChannel> channels,
  ) async {
    if (channels.isEmpty) return channels;

    final youtube = await _getYouTubeApi();
    if (youtube == null) {
      print(
          '⚠️ [YoutubeSyncService] YouTube API unavailable — skipping topic enrichment');
      return channels;
    }

    // Build a lookup map: channelId → channel
    final channelMap = {for (final c in channels) c.channelId: c};
    final enriched = <String, YoutubeArtistChannel>{};

    // Process in batches of 50 (API limit per request)
    final ids = channels.map((c) => c.channelId).toList();
    for (var i = 0; i < ids.length; i += 50) {
      final chunk = ids.sublist(i, (i + 50).clamp(0, ids.length));

      try {
        final res = await youtube.channels.list(
          ['topicDetails', 'snippet'],
          id: chunk,
        );

        if (res.items == null) continue;

        for (final item in res.items!) {
          final id = item.id;
          if (id == null || !channelMap.containsKey(id)) continue;

          final base = channelMap[id]!;
          final topics = item.topicDetails?.topicCategories ?? [];
          final titleLower = item.snippet?.title?.toLowerCase() ?? '';
          final customUrl = item.snippet?.customUrl?.toLowerCase() ?? '';

          final bool isMusicByTopic =
              topics.any((url) => url.contains('/Music'));
          final bool isMusicByTitle = titleLower.endsWith(' - topic') ||
              titleLower.contains('vevo') ||
              customUrl.contains('vevo');

          final bool isMusic = isMusicByTopic || isMusicByTitle;

          enriched[id] = base.copyWith(
            isMusicArtist: isMusic,
            topicCategories: topics,
          );
        }
      } catch (e) {
        print(
            '⚠️ [YoutubeSyncService] Error fetching topicDetails for chunk: $e');
        // On error, keep original (isMusicArtist = false)
        for (final id in chunk) {
          if (!enriched.containsKey(id) && channelMap.containsKey(id)) {
            enriched[id] = channelMap[id]!;
          }
        }
      }
    }

    // Merge: use enriched version where available, original otherwise
    final result = channels.map((c) => enriched[c.channelId] ?? c).toList();

    final musicCount = result.where((c) => c.isMusicArtist).length;
    print(
        '🟢 [YoutubeSyncService] Topic enrichment complete: '
        '${result.length} total, $musicCount identified as music artists');

    return result;
  }

  // ─── Music Filter ─────────────────────────────────────────────────────────

  /// Parses ISO 8601 duration strings (e.g. PT3M15S, PT1H2M5S) to Duration.
  Duration? _parseIso8601Duration(String? isoDuration) {
    if (isoDuration == null || !isoDuration.startsWith('PT')) return null;

    int hours = 0;
    int minutes = 0;
    int seconds = 0;

    final hoursRegex = RegExp(r'(\d+)H');
    final minutesRegex = RegExp(r'(\d+)M');
    final secondsRegex = RegExp(r'(\d+)S');

    final hMatch = hoursRegex.firstMatch(isoDuration);
    if (hMatch != null) {
      hours = int.parse(hMatch.group(1)!);
    }

    final mMatch = minutesRegex.firstMatch(isoDuration);
    if (mMatch != null) {
      minutes = int.parse(mMatch.group(1)!);
    }

    final sMatch = secondsRegex.firstMatch(isoDuration);
    if (sMatch != null) {
      seconds = int.parse(sMatch.group(1)!);
    }

    return Duration(hours: hours, minutes: minutes, seconds: seconds);
  }

  /// Filters a list of tracks to keep only those in the "Music" category (ID "10"),
  /// from Topic/Vevo channels, or that pass basic heuristic checks.
  Future<List<YoutubeTrack>> filterMusicOnly(List<YoutubeTrack> tracks) async {
    final blacklist = [
      'shorts', '#shorts', 'tiktok', 'fashion', 'outfit', 'haul',
      'vlog', 'trailer', 'teaser', 'clip', 'sound effect', 'preview',
      'unboxing', 'review', 'makeup', 'grwm', 'lookbook', 'style'
    ];

    final candidates = <YoutubeTrack>[];
    for (final track in tracks) {
      final title = track.title.toLowerCase();
      final artist = track.artistName.toLowerCase();

      if (blacklist.any((word) => title.contains(word) || artist.contains(word))) {
        continue;
      }

      if (track.duration != null && track.duration!.inSeconds <= 60) {
        continue;
      }

      candidates.add(track);
    }

    final youtube = await _getYouTubeApi();
    if (youtube == null) {
      print(
          '⚠️ [YoutubeSyncService] YouTube API client not available, returning locally filtered tracks');
      return candidates;
    }

    final filtered = <YoutubeTrack>[];

    // Chunk the track IDs in batches of 50 (maximum allowed by YouTube API)
    for (var i = 0; i < candidates.length; i += 50) {
      final chunk = candidates.sublist(
          i, (i + 50).clamp(0, candidates.length));
      final ids = chunk.map((t) => t.id).toList();

      try {
        final res = await youtube.videos.list(
          ['snippet', 'contentDetails'],
          id: ids,
        );

        if (res.items != null) {
          final musicIds = res.items!
              .where((item) {
                final categoryId = item.snippet?.categoryId;
                final channelTitle =
                    item.snippet?.channelTitle?.toLowerCase() ?? '';
                final videoTitle = item.snippet?.title?.toLowerCase() ?? '';

                // Parse duration to exclude shorts / short audio clips (<= 60s)
                final durationStr = item.contentDetails?.duration;
                final duration = _parseIso8601Duration(durationStr);
                if (duration != null && duration.inSeconds <= 60) {
                  return false;
                }

                // Exclude explicit non-music keywords in titles
                final blacklist = [
                  'shorts', '#shorts', 'tiktok', 'fashion', 'outfit', 'haul',
                  'vlog', 'trailer', 'teaser', 'clip', 'sound effect', 'preview',
                  'unboxing', 'review', 'makeup', 'grwm', 'lookbook', 'style'
                ];
                if (blacklist.any((word) => videoTitle.contains(word))) {
                  return false;
                }

                // Music category
                if (categoryId == '10') return true;

                // Official Topic or Vevo channel
                if (channelTitle.endsWith(' - topic') ||
                    channelTitle.contains('vevo')) {
                  return true;
                }

                return false;
              })
              .map((item) => item.id)
              .toSet();

          for (final track in chunk) {
            if (musicIds.contains(track.id)) {
              filtered.add(track);
            }
          }
        }
      } catch (e) {
        print('⚠️ [YoutubeSyncService] Error filtering music chunk: $e');
        // On error, fallback to keep the track as a safeguard
        filtered.addAll(chunk);
      }
    }

    return filtered;
  }
}
