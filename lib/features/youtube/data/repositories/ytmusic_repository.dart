import 'package:dart_ytmusic_api/yt_music.dart';
import 'package:dart_ytmusic_api/types.dart';
import 'package:dart_ytmusic_api/parsers/song_parser.dart';
import 'package:dart_ytmusic_api/utils/traverse.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/youtube_track.dart';
import '../models/youtube_playlist.dart';

/// Home section returned by YouTube Music's home feed
class YTMusicHomeSection {
  final String title;
  final List<YoutubeTrack> tracks;

  const YTMusicHomeSection({required this.title, required this.tracks});
}

/// A timed lyrics line (for karaoke-style display)
class TimedLyricLine {
  final Duration time;
  final String text;

  const TimedLyricLine({required this.time, required this.text});
}

/// Repository that wraps dart_ytmusic_api for all metadata operations.
///
/// Audio streaming is handled separately by YoutubeStreamResolver
/// (which uses youtube_explode_dart) — this repo only provides metadata.
class YTMusicRepository {
  final YTMusic _ytMusic;

  YTMusicRepository(this._ytMusic);

  // ─── Search ───────────────────────────────────────────────────────────────

  /// Search YouTube Music catalog for songs matching [query].
  /// Returns proper square album art and full song metadata.
  Future<List<YoutubeTrack>> searchSongs(String query) async {
    try {
      final results = await _ytMusic.searchSongs(query);
      if (results.isNotEmpty) {
        return results.map<YoutubeTrack>(_mapSong).toList();
      }

      final searchData = await _ytMusic.constructRequest(
        "search",
        body: {
          "query": query,
          "params": "Eg-KAQwIARAAGAAgACgAMABqChAEEAMQCRAFEAo="
        },
      );
      final resultsList = traverseList(searchData, ["musicResponsiveListItemRenderer"]);
      final tracks = <YoutubeTrack>[];
      for (final r in resultsList) {
        try {
          final song = SongParser.parseSearchResult(r);
          final extractedId = _extractVideoIdFromRenderer(r);
          final finalId = (extractedId != null && extractedId.isNotEmpty) ? extractedId : song.videoId;
          
          tracks.add(YoutubeTrack(
            id: finalId,
            title: song.name,
            artistName: song.artist?.name ?? 'Unknown Artist',
            artistId: song.artist?.artistId,
            albumName: song.album?.name,
            albumId: song.album?.albumId,
            artworkUrl: _pickBestThumbnail(song.thumbnails),
            duration: song.duration != null ? Duration(seconds: song.duration!) : null,
            isMusicVideo: _isThumbnailWidescreen(song.thumbnails),
          ));
        } catch (e) {
          print('⚠️ [YTMusic] Error parsing search result row: $e');
        }
      }
      return tracks;
    } catch (e) {
      print('⚠️ [YTMusic] searchSongs failed: $e');
      return [];
    }
  }

  /// Search for music videos matching [query].
  Future<List<YoutubeTrack>> searchVideos(String query) async {
    try {
      final results = await _ytMusic.searchVideos(query);
      return results.map<YoutubeTrack>((v) {
        return YoutubeTrack(
          id: v.videoId,
          title: v.name,
          artistName: v.artist?.name ?? 'Unknown Artist',
          artistId: v.artist?.artistId,
          artworkUrl: _pickBestThumbnail(v.thumbnails),
          duration: v.duration != null ? Duration(seconds: v.duration!) : null,
          isMusicVideo: true,
        );
      }).toList();
    } catch (e) {
      print('⚠️ [YTMusic] searchVideos failed: $e');
      return [];
    }
  }

  /// Search for artists by name.
  Future<List<Map<String, dynamic>>> searchArtists(String query) async {
    try {
      final results = await _ytMusic.searchArtists(query);
      return results
          .map((a) => {
                'id': a.artistId,
                'name': a.name,
                'thumbnail': _pickBestThumbnail(a.thumbnails),
              })
          .toList();
    } catch (e) {
      print('⚠️ [YTMusic] searchArtists failed: $e');
      return [];
    }
  }

  /// Search for albums by name.
  Future<List<Map<String, dynamic>>> searchAlbums(String query) async {
    try {
      final results = await _ytMusic.searchAlbums(query);
      return results
          .map((a) => {
                'id': a.albumId,
                'title': a.name,
                'artist': a.artist?.name ?? '',
                'thumbnail': _pickBestThumbnail(a.thumbnails),
              })
          .toList();
    } catch (e) {
      print('⚠️ [YTMusic] searchAlbums failed: $e');
      return [];
    }
  }

  // ─── Home Feed ────────────────────────────────────────────────────────────

  /// Fetch YouTube Music's home feed sections (e.g. "Top picks", "Trending").
  Future<List<YTMusicHomeSection>> getHomeSections() async {
    try {
      final sections = await _ytMusic.getHomeSections();
      final result = <YTMusicHomeSection>[];

      for (final section in sections) {
        final tracks = <YoutubeTrack>[];
        for (final item in section.contents) {
          try {
            if (item is SongDetailed) {
              tracks.add(_mapSong(item));
            } else if (item is VideoDetailed) {
              tracks.add(YoutubeTrack(
                id: item.videoId,
                title: item.name,
                artistName: item.artist?.name ?? 'Unknown Artist',
                artistId: item.artist?.artistId,
                artworkUrl: _pickBestThumbnail(item.thumbnails),
                duration: item.duration != null ? Duration(seconds: item.duration!) : null,
                isMusicVideo: true,
              ));
            } else if (item is PlaylistDetailed) {
              tracks.add(YoutubeTrack(
                id: 'playlist_${item.playlistId}',
                title: item.name,
                artistName: 'Playlist',
                artworkUrl: _pickBestThumbnail(item.thumbnails),
              ));
            } else if (item is AlbumDetailed) {
              tracks.add(YoutubeTrack(
                id: 'album_${item.albumId}',
                title: item.name,
                artistName: item.artist?.name ?? 'Album',
                artworkUrl: _pickBestThumbnail(item.thumbnails),
                albumId: item.albumId,
                artistId: item.artist?.artistId,
              ));
            }
          } catch (_) {}
        }
        if (tracks.isNotEmpty) {
          result.add(YTMusicHomeSection(title: section.title ?? 'Music', tracks: tracks));
        }
      }

      return result;
    } catch (e) {
      print('⚠️ [YTMusic] getHomeSections failed: $e');
      return [];
    }
  }

  // ─── Song Details ─────────────────────────────────────────────────────────

  /// Get enriched song metadata by video ID.
  Future<YoutubeTrack?> getSongDetails(String videoId) async {
    try {
      final song = await _ytMusic.getSong(videoId);
      return YoutubeTrack(
        id: song.videoId,
        title: song.name,
        artistName: song.artist.name,
        artistId: song.artist.artistId,
        albumName: null, // SongFull does not provide album in basic getSong
        albumId: null,
        artworkUrl: _pickBestThumbnail(song.thumbnails),
        duration: song.duration != null ? Duration(seconds: song.duration!) : null,
      );
    } catch (e) {
      print('⚠️ [YTMusic] getSongDetails failed for $videoId: $e');
      return null;
    }
  }

  // ─── Lyrics ───────────────────────────────────────────────────────────────

  /// Get plain text lyrics for a video.
  Future<String?> getLyrics(String videoId) async {
    try {
      final lyrics = await _ytMusic.getLyrics(videoId);
      return lyrics;
    } catch (e) {
      print('⚠️ [YTMusic] getLyrics failed for $videoId: $e');
      return null;
    }
  }

  /// Get time-synced lyrics for karaoke-style display.
  Future<List<TimedLyricLine>> getTimedLyrics(String videoId) async {
    try {
      final result = await _ytMusic.getTimedLyrics(videoId);
      if (result == null || result.timedLyricsData.isEmpty) return [];
      return result.timedLyricsData
          .map((l) => TimedLyricLine(
                time: Duration(milliseconds: (l.cueRange?.startTimeMilliseconds ?? 0).toInt()),
                text: l.lyricLine ?? '',
              ))
          .toList();
    } catch (e) {
      print('⚠️ [YTMusic] getTimedLyrics failed for $videoId: $e');
      return [];
    }
  }

  // ─── Up Next / Queue ──────────────────────────────────────────────────────

  /// Get suggested "up next" songs after a given video.
  Future<List<YoutubeTrack>> getUpNexts(String videoId) async {
    try {
      final results = await _ytMusic.getUpNexts(videoId);
      return results.map<YoutubeTrack>((s) {
        return YoutubeTrack(
          id: s.videoId,
          title: s.title,
          artistName: s.artists?.name ?? '',
          artistId: s.artists?.artistId,
          albumName: s.album?.name,
          albumId: s.album?.albumId,
          artworkUrl: _pickBestThumbnail(s.thumbnails),
          duration: s.duration != null ? Duration(seconds: s.duration!) : null,
        );
      }).toList();
    } catch (e) {
      print('⚠️ [YTMusic] getUpNexts failed for $videoId: $e');
      return [];
    }
  }

  // ─── Artist ───────────────────────────────────────────────────────────────

  /// Get artist top songs.
  Future<List<YoutubeTrack>> getArtistSongs(String artistId) async {
    try {
      if (artistId.startsWith('UC') || artistId.startsWith('FMyoutube_artist')) {
        final songs = await _ytMusic.getArtistSongs(artistId);
        if (songs.isNotEmpty) {
          return songs.map<YoutubeTrack>(_mapSong).toList();
        }
      }
    } catch (e) {
      print('⚠️ [YTMusic] getArtistSongs failed for $artistId: $e');
    }

    // Fallback: search songs by the artist's name (resolves empty screens for fallback onboarding IDs)
    try {
      final query = artistId.replaceAll('_', ' ');
      print('🔍 [YTMusic] Falling back to search songs for artist: "$query"');
      final songs = await searchSongs(query);
      return songs;
    } catch (e) {
      print('⚠️ [YTMusic] Fallback search songs failed for $artistId: $e');
      return [];
    }
  }

  // ─── Album ────────────────────────────────────────────────────────────────

  /// Get all songs in an album.
  Future<List<YoutubeTrack>> getAlbumSongs(String albumId) async {
    try {
      final album = await _ytMusic.getAlbum(albumId);
      final songs = album.songs.map((s) {
        return YoutubeTrack(
          id: s.videoId,
          title: s.name,
          artistName: s.artist?.name ?? album.artist?.name ?? '',
          artistId: s.artist?.artistId ?? album.artist?.artistId,
          albumName: album.name,
          albumId: albumId,
          artworkUrl: _pickBestThumbnail(album.thumbnails),
          duration: s.duration != null ? Duration(seconds: s.duration!) : null,
        );
      }).toList();
      if (songs.isNotEmpty) return songs;
    } catch (e) {
      print('⚠️ [YTMusic] getAlbumSongs failed for $albumId: $e');
    }

    // Fallback: load as playlist (since YouTube Music search results sometimes contain playlist IDs as albums)
    try {
      print('🔍 [YTMusic] getAlbumSongs fallback: loading $albumId as playlist...');
      final playlistSongs = await getPlaylistSongs(albumId);
      if (playlistSongs.isNotEmpty) {
        return playlistSongs;
      }
    } catch (e) {
      print('⚠️ [YTMusic] getAlbumSongs fallback playlist check failed: $e');
    }

    return [];
  }

  // ─── Playlist ──────────────────────────────────────────────────────────────

  /// Get all songs in a playlist.
  Future<List<YoutubeTrack>> getPlaylistSongs(String playlistId) async {
    try {
      final browseId = playlistId.startsWith('VL') ? playlistId : 'VL$playlistId';
      final response = await _ytMusic.constructRequest('browse', body: {'browseId': browseId});
      if (response != null) {
        final tracks = _extractTracksFromJson(response);
        if (tracks.isNotEmpty) {
          print('🟢 [YTMusic] Custom crawler loaded ${tracks.length} tracks for playlist $playlistId');
          return tracks;
        }
      }
    } catch (e) {
      print('⚠️ [YTMusic] Custom crawl failed for $playlistId: $e');
    }

    try {
      final songs = await _ytMusic.getPlaylistVideos(playlistId);
      if (songs.isEmpty) throw Exception('Empty playlist contents in YTMusic');
      return songs.map<YoutubeTrack>((s) {
        return YoutubeTrack(
          id: s.videoId,
          title: s.name,
          artistName: s.artist?.name ?? 'Unknown Artist',
          artistId: s.artist?.artistId,
          artworkUrl: _pickBestThumbnail(s.thumbnails),
          duration: s.duration != null ? Duration(seconds: s.duration!) : null,
          isMusicVideo: _isThumbnailWidescreen(s.thumbnails),
        );
      }).toList();
    } catch (e) {
      print('⚠️ [YTMusic] getPlaylistSongs failed for $playlistId: $e');
      return [];
    }
  }

  // ─── Playlist Search ──────────────────────────────────────────────────────

  /// Search YouTube Music catalog specifically for playlists.
  Future<List<YoutubePlaylist>> searchPlaylists(String query) async {
    try {
      final results = await _ytMusic.searchPlaylists(query);
      return results.map((p) {
        return YoutubePlaylist(
          id: p.playlistId,
          title: p.name,
          coverUrl: _pickBestThumbnail(p.thumbnails),
          author: p.artist?.name ?? 'YouTube Music',
        );
      }).toList();
    } catch (e) {
      print('⚠️ [YTMusic] searchPlaylists failed for "$query": $e');
      return [];
    }
  }

  // ─── User Playback History ────────────────────────────────────────────────

  /// Fetch the user's actual YouTube Music watch history (their most played/recent songs).
  /// Recursive scraper helper to cleanly extract YoutubeTracks from any InnerTube JSON response
  List<YoutubeTrack> _extractTracksFromJson(dynamic json) {
    final tracks = <YoutubeTrack>[];
    if (json == null) return tracks;

    if (json is Map) {
      if (json.containsKey('musicResponsiveListItemRenderer')) {
        final renderer = json['musicResponsiveListItemRenderer'];
        if (renderer != null) {
          try {
            final videoId = renderer['playlistItemData']?['videoId'] ?? renderer['navigationEndpoint']?['watchEndpoint']?['videoId'];
            final flexColumns = renderer['flexColumns'];
            if (videoId != null && flexColumns is List && flexColumns.isNotEmpty) {
              final title = flexColumns[0]?['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs']?[0]?['text'];
              
              String artistName = 'Unknown Artist';
              String? artistId;
              if (flexColumns.length > 1) {
                final artistRuns = flexColumns[1]?['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs'];
                if (artistRuns is List && artistRuns.isNotEmpty) {
                  artistName = artistRuns[0]?['text'] ?? 'Unknown Artist';
                  artistId = artistRuns[0]?['navigationEndpoint']?['browseEndpoint']?['browseId'];
                }
              }
              
              final thumbnails = renderer['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'];
              String? artworkUrl;
              if (thumbnails is List && thumbnails.isNotEmpty) {
                artworkUrl = thumbnails.first['url'];
              }

              final watchEndpoint = renderer['navigationEndpoint']?['watchEndpoint'] ?? 
                                    renderer['overlay']?['musicItemThumbnailOverlayRenderer']?['content']?['musicPlayButtonRenderer']?['playNavigationEndpoint']?['watchEndpoint'];
              final watchConfig = watchEndpoint?['watchEndpointMusicSupportedConfigs']?['watchEndpointMusicConfig'];
              final musicVideoType = watchConfig?['musicVideoType'];

              // Exclude UGC (User Generated Content) to filter out Shorts and non-music videos
              if (musicVideoType == 'MUSIC_VIDEO_TYPE_UGC') {
                return tracks;
              }

              bool isVideo = false;
              if (musicVideoType == 'MUSIC_VIDEO_TYPE_OMV') {
                isVideo = true;
              } else if (musicVideoType == 'MUSIC_VIDEO_TYPE_ATV') {
                isVideo = false;
              } else {
                if (thumbnails is List && thumbnails.isNotEmpty) {
                  final first = thumbnails.first;
                  final width = first['width'];
                  final height = first['height'];
                  if (width is num && height is num && width != height) {
                    isVideo = true;
                  }
                }
              }

              tracks.add(YoutubeTrack(
                id: videoId,
                title: title ?? 'Unknown Title',
                artistName: artistName,
                artistId: artistId,
                artworkUrl: artworkUrl,
                isMusicVideo: isVideo,
              ));
            }
          } catch (_) {}
        }
      } else {
        for (final val in json.values) {
          tracks.addAll(_extractTracksFromJson(val));
        }
      }
    } else if (json is List) {
      for (final item in json) {
        tracks.addAll(_extractTracksFromJson(item));
      }
    }
    return tracks;
  }

  /// Fetch the user's actual YouTube Music watch history (their most played/recent songs).
  Future<List<YoutubeTrack>> getHistory() async {
    try {
      final data = await _ytMusic.constructRequest("browse", body: {"browseId": "FEmusic_history"});
      if (data == null) return [];
      final tracks = _extractTracksFromJson(data);
      print('🟢 [YTMusic] Synced ${tracks.length} history tracks recursively from user account');
      return tracks;
    } catch (e) {
      print('⚠️ [YTMusic] getHistory failed: $e');
      return [];
    }
  }

  // ─── User Liked Music ─────────────────────────────────────────────────────

  /// Fetch the user's actual YouTube Music Liked Songs (FEmusic_liked_videos) using the InnerTube browse API.
  Future<List<YoutubeTrack>> getLikedMusicSynced() async {
    try {
      final data = await _ytMusic.constructRequest("browse", body: {"browseId": "FEmusic_liked_videos"});
      if (data == null) return [];
      final tracks = _extractTracksFromJson(data);
      print('🟢 [YTMusic] Synced ${tracks.length} Liked Songs recursively from user account');
      return tracks;
    } catch (e) {
      print('⚠️ [YTMusic] getLikedMusicSynced failed: $e');
      return [];
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────


  bool _isThumbnailWidescreen(List<ThumbnailFull> thumbnails) {
    if (thumbnails.isEmpty) return false;
    final first = thumbnails.first;
    return first.width != first.height;
  }

  String? _extractVideoIdFromRenderer(dynamic renderer) {
    if (renderer is! Map) return null;
    
    // 1. Try playlistItemData
    var videoId = renderer['playlistItemData']?['videoId'];
    if (videoId is String && videoId.isNotEmpty) return videoId;
    
    // 2. Try navigationEndpoint -> watchEndpoint
    videoId = renderer['navigationEndpoint']?['watchEndpoint']?['videoId'];
    if (videoId is String && videoId.isNotEmpty) return videoId;

    // 3. Try overlay -> musicItemThumbnailOverlayRenderer -> content -> musicPlayButtonRenderer -> playNavigationEndpoint -> watchEndpoint
    videoId = renderer['overlay']
        ?['musicItemThumbnailOverlayRenderer']
        ?['content']
        ?['musicPlayButtonRenderer']
        ?['playNavigationEndpoint']
        ?['watchEndpoint']
        ?['videoId'];
    if (videoId is String && videoId.isNotEmpty) return videoId;

    // 4. Traverse runs to find watchEndpoint -> videoId
    final flexColumns = renderer['flexColumns'];
    if (flexColumns is List) {
      for (final col in flexColumns) {
        final runs = col?['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs'];
        if (runs is List) {
          for (final run in runs) {
            final runVideoId = run?['navigationEndpoint']?['watchEndpoint']?['videoId'];
            if (runVideoId is String && runVideoId.isNotEmpty) {
              return runVideoId;
            }
          }
        }
      }
    }

    // 5. Traverse menu items
    final menuItems = renderer['menu']?['menuRenderer']?['items'];
    if (menuItems is List) {
      for (final item in menuItems) {
        // Check watchEndpoint
        var endpointVideoId = item?['menuNavigationItemRenderer']?['navigationEndpoint']?['watchEndpoint']?['videoId'];
        if (endpointVideoId is String && endpointVideoId.isNotEmpty) return endpointVideoId;
        
        // Check serviceEndpoint -> queueAddEndpoint
        endpointVideoId = item?['menuServiceItemRenderer']?['serviceEndpoint']?['queueAddEndpoint']?['queueTarget']?['videoId'];
        if (endpointVideoId is String && endpointVideoId.isNotEmpty) return endpointVideoId;
      }
    }

    return null;
  }

  YoutubeTrack _mapSong(SongDetailed song) {
    return YoutubeTrack(
      id: song.videoId,
      title: song.name,
      artistName: song.artist?.name ?? 'Unknown Artist',
      artistId: song.artist?.artistId,
      albumName: song.album?.name,
      albumId: song.album?.albumId,
      artworkUrl: _pickBestThumbnail(song.thumbnails),
      duration: song.duration != null ? Duration(seconds: song.duration!) : null,
      isMusicVideo: _isThumbnailWidescreen(song.thumbnails),
    );
  }

  /// Pick the highest-resolution thumbnail available.
  /// YouTube Music thumbnails are square (1:1) — much better than YT video thumbnails.
  String? _pickBestThumbnail(List<ThumbnailFull> thumbnails) {
    if (thumbnails.isEmpty) return null;
    // Sort descending by width to get largest first
    final sorted = [...thumbnails]
      ..sort((a, b) => b.width.compareTo(a.width));
    final bestUrl = sorted.first.url;

    // Google's CDN uses parameters like =w120-h120 or =w226-h226 or =s90
    // We regex replace the size parameter to get a beautiful high-res image (500x500)
    try {
      final regExpSize = RegExp(r'=[ws]\d+.*');
      if (bestUrl.contains(regExpSize)) {
        return bestUrl.replaceAll(regExpSize, '=w500-h500-l90-rj');
      }
    } catch (_) {}
    return bestUrl;
  }

  /// Fetch the user's actual playlists from their YouTube Music library
  Future<List<YoutubePlaylist>> getLibraryPlaylists() async {
    final list = <YoutubePlaylist>[];
    final seenIds = <String>{};

    for (final browseId in ["FEmusic_to_go_playlists", "FEmusic_liked_playlists"]) {
      try {
        final data = await _ytMusic.constructRequest("browse", body: {"browseId": browseId});
        if (data != null) {
          final parsed = _extractPlaylistsFromJson(data);
          for (final p in parsed) {
            if (seenIds.add(p.id)) {
              list.add(p);
            }
          }
        }
      } catch (e) {
        print('⚠️ [YTMusic] getLibraryPlaylists failed for $browseId: $e');
      }
    }
    return list;
  }

  List<YoutubePlaylist> _extractPlaylistsFromJson(dynamic json) {
    final playlists = <YoutubePlaylist>[];
    if (json == null) return playlists;

    if (json is Map) {
      if (json.containsKey('playlistId')) {
        final playlistId = json['playlistId'];
        final title = json['title']?['runs']?[0]?['text'] ?? json['name'] ?? 'Playlist';
        final thumbnails = json['thumbnail']?['thumbnails'] ?? json['thumbnails'];
        String? coverUrl;
        if (thumbnails is List && thumbnails.isNotEmpty) {
          coverUrl = thumbnails.first['url'];
        }
        if (playlistId is String) {
          playlists.add(YoutubePlaylist(
            id: playlistId,
            title: title,
            coverUrl: coverUrl,
            author: 'YouTube Music',
          ));
        }
      } else if (json.containsKey('musicResponsiveListItemRenderer')) {
        final renderer = json['musicResponsiveListItemRenderer'];
        final browseId = renderer['navigationEndpoint']?['browseEndpoint']?['browseId'];
        if (browseId is String && browseId.startsWith('VL')) {
          final playlistId = browseId.replaceFirst('VL', '');
          final title = renderer['flexColumns']?[0]?['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs']?[0]?['text'];
          final thumbnails = renderer['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'];
          String? coverUrl;
          if (thumbnails is List && thumbnails.isNotEmpty) {
            coverUrl = thumbnails.first['url'];
          }
          playlists.add(YoutubePlaylist(
            id: playlistId,
            title: title ?? 'Playlist',
            coverUrl: coverUrl,
            author: 'YouTube Music',
          ));
        }
      } else {
        for (final val in json.values) {
          playlists.addAll(_extractPlaylistsFromJson(val));
        }
      }
    } else if (json is List) {
      for (final item in json) {
        playlists.addAll(_extractPlaylistsFromJson(item));
      }
    }
    return playlists;
  }

  List<YoutubeTrack> extractTracksFromJson(dynamic json) {
    return _extractTracksFromJson(json);
  }

  List<YoutubePlaylist> extractPlaylistsFromJson(dynamic json) {
    return _extractPlaylistsFromJson(json);
  }
}
