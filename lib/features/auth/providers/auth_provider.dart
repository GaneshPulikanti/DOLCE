import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../data/models/youtube_playlist.dart';
import '../data/models/youtube_artist_channel.dart';
import '../data/services/google_auth_service.dart';
import '../data/services/youtube_sync_service.dart';
import '../../youtube/data/models/youtube_track.dart';


// ── Authentication Providers ───────────────────────────────────────────────

final googleAuthServiceProvider = Provider<GoogleAuthService>((ref) {
  final service = GoogleAuthService();
  // Trigger silent sign-in exactly once on startup/initialization
  Future.microtask(() => service.signInSilently());
  return service;
});

final youtubeSyncServiceProvider = Provider<YoutubeSyncService>((ref) {
  final authService = ref.watch(googleAuthServiceProvider);
  return YoutubeSyncService(authService.googleSignIn);
});

/// Exposes the GoogleSignInAccount stream.
final googleUserProvider = StreamProvider<GoogleSignInAccount?>((ref) {
  final authService = ref.watch(googleAuthServiceProvider);
  final controller = StreamController<GoogleSignInAccount?>();
  
  // Seed the initial value synchronously to prevent any loading state hang
  controller.add(authService.currentUser);
  
  final subscription = authService.onCurrentUserChanged.listen((user) {
    if (!controller.isClosed) {
      controller.add(user);
    }
  });
  
  ref.onDispose(() {
    subscription.cancel();
    controller.close();
  });
  
  return controller.stream;
});

// ── Synced Library State & Notifier ──────────────────────────────────────────

class SyncedLibraryState {
  final List<YoutubePlaylist> playlists;
  final Map<String, List<YoutubeTrack>> playlistTracks; // playlistId -> tracks
  final List<YoutubeTrack> likedSongs;

  /// All channels the user is subscribed to (stored but not all used for recs).
  final List<YoutubeArtistChannel> allSubscriptions;

  /// Subset of [allSubscriptions] where [isMusicArtist] == true.
  /// These are used as recommendation seeds.
  final List<YoutubeArtistChannel> musicArtists;

  final bool isLoading;
  final String? syncError;

  const SyncedLibraryState({
    this.playlists = const [],
    this.playlistTracks = const {},
    this.likedSongs = const [],
    this.allSubscriptions = const [],
    this.musicArtists = const [],
    this.isLoading = false,
    this.syncError,
  });

  SyncedLibraryState copyWith({
    List<YoutubePlaylist>? playlists,
    Map<String, List<YoutubeTrack>>? playlistTracks,
    List<YoutubeTrack>? likedSongs,
    List<YoutubeArtistChannel>? allSubscriptions,
    List<YoutubeArtistChannel>? musicArtists,
    bool? isLoading,
    String? syncError,
  }) {
    return SyncedLibraryState(
      playlists: playlists ?? this.playlists,
      playlistTracks: playlistTracks ?? this.playlistTracks,
      likedSongs: likedSongs ?? this.likedSongs,
      allSubscriptions: allSubscriptions ?? this.allSubscriptions,
      musicArtists: musicArtists ?? this.musicArtists,
      isLoading: isLoading ?? this.isLoading,
      syncError: syncError ?? this.syncError,
    );
  }
}

class SyncedLibraryNotifier extends StateNotifier<SyncedLibraryState> {
  final YoutubeSyncService _syncService;
  final Ref _ref;

  SyncedLibraryNotifier(this._syncService, this._ref)
      : super(const SyncedLibraryState()) {
    _loadCache();

    // Auto-sync when login status transitions from logged-out to logged-in
    _ref.listen<AsyncValue<GoogleSignInAccount?>>(googleUserProvider,
        (previous, next) {
      final user = next.value;
      if (user != null && (previous == null || previous.value == null)) {
        print(
            '🔄 [SyncedLibrary] Google account connected! Automatically triggering library sync...');
        syncAll();
      }
    });
  }

  static const _keyPlaylists        = 'yt_sync_playlists';
  static const _keyLikedSongs       = 'yt_sync_liked_songs';
  static const _keyAllSubscriptions = 'yt_sync_subscriptions';
  static const _keyMusicArtists     = 'yt_sync_music_artists';

  static String _keyPlaylistTracks(String id) => 'yt_sync_playlist_tracks_$id';

  // ── Cache Loading ────────────────────────────────────────────────────────

  Future<void> _loadCache() async {
    state = state.copyWith(isLoading: true);
    try {
      final box = Hive.box('synced_library');

      // Playlists
      final playlistsJson = box.get(_keyPlaylists) as String?;
      var playlists = <YoutubePlaylist>[];
      if (playlistsJson != null) {
        final decoded = json.decode(playlistsJson) as List<dynamic>;
        playlists = decoded
            .map((e) => YoutubePlaylist.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      // Liked songs
      final likedJson = box.get(_keyLikedSongs) as String?;
      var likedSongs = <YoutubeTrack>[];
      if (likedJson != null) {
        final decoded = json.decode(likedJson) as List<dynamic>;
        likedSongs = decoded
            .map((e) => _trackFromJson(e as Map<String, dynamic>))
            .toList();
      }

      // All subscriptions
      final subsJson = box.get(_keyAllSubscriptions) as String?;
      var allSubscriptions = <YoutubeArtistChannel>[];
      if (subsJson != null) {
        final decoded = json.decode(subsJson) as List<dynamic>;
        allSubscriptions = decoded
            .map((e) =>
                YoutubeArtistChannel.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      // Music-identified artist channels
      final artistsJson = box.get(_keyMusicArtists) as String?;
      var musicArtists = <YoutubeArtistChannel>[];
      if (artistsJson != null) {
        final decoded = json.decode(artistsJson) as List<dynamic>;
        musicArtists = decoded
            .map((e) =>
                YoutubeArtistChannel.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      // Playlist tracks
      var playlistTracks = <String, List<YoutubeTrack>>{};
      for (final p in playlists) {
        final tracksJson = box.get(_keyPlaylistTracks(p.id)) as String?;
        if (tracksJson != null) {
          final decoded = json.decode(tracksJson) as List<dynamic>;
          playlistTracks[p.id] =
              decoded.map((e) => _trackFromJson(e as Map<String, dynamic>)).toList();
        }
      }

      state = SyncedLibraryState(
        playlists: playlists,
        playlistTracks: playlistTracks,
        likedSongs: likedSongs,
        allSubscriptions: allSubscriptions,
        musicArtists: musicArtists,
        isLoading: false,
      );

      // If cache is empty but user is signed in, trigger a fresh sync
      final googleUser = _ref.read(googleUserProvider).value;
      if (googleUser != null && likedSongs.isEmpty && allSubscriptions.isEmpty) {
        print(
            '🔄 [SyncedLibrary] Cache is empty but user is logged in. Auto-syncing on startup...');
        Future.delayed(const Duration(milliseconds: 500), () => syncAll());
      }
    } catch (e) {
      print('🔴 [SyncedLibraryNotifier] Error loading cache: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  // ── Full Sync ────────────────────────────────────────────────────────────

  Future<void> syncAll() async {
    state = state.copyWith(isLoading: true, syncError: null);
    try {
      final box = Hive.box('synced_library');

      // 1. Playlists
      print(
          '🔄 [SyncedLibrary] Syncing user playlists using official Google YouTube API...');
      List<YoutubePlaylist> playlists = [];
      try {
        playlists = await _syncService.fetchMyPlaylists();
        print(
            '🟢 [SyncedLibrary] Synced ${playlists.length} playlists from official YouTube API');
      } catch (e) {
        print('⚠️ [SyncedLibrary] Failed official YouTube API playlists sync: $e');
      }

      // 2. Liked songs (capped at 500 most recent)
      print(
          '🔄 [SyncedLibrary] Syncing Liked Songs (max 500) using official Google YouTube API...');
      List<YoutubeTrack> likedSongs = [];
      try {
        likedSongs = await _syncService.fetchLikedMusic(maxItems: 500);
        print(
            '🟢 [SyncedLibrary] Synced ${likedSongs.length} Liked Songs from official YouTube API');
      } catch (e) {
        print(
            '⚠️ [SyncedLibrary] Failed official YouTube API Liked Songs sync: $e');
      }

      // 3. Playlist tracks
      var playlistTracks = <String, List<YoutubeTrack>>{};
      for (final playlist in playlists) {
        print(
            '🔄 [SyncedLibrary] Syncing tracks for playlist: ${playlist.title} (${playlist.id})...');
        List<YoutubeTrack> rawTracks = [];
        try {
          rawTracks = await _syncService.fetchPlaylistItems(playlist.id);
          print(
              '🟢 [SyncedLibrary] Synced ${rawTracks.length} tracks for playlist ${playlist.title}');
        } catch (e) {
          print(
              '⚠️ [SyncedLibrary] Playlist tracks sync failed for ${playlist.id}: $e');
        }

        playlistTracks[playlist.id] = rawTracks;

        // Cache this playlist's tracks immediately in Hive
        await box.put(
            _keyPlaylistTracks(playlist.id),
            json.encode(rawTracks.map((t) => _trackToJson(t)).toList()));
      }

      // 4. Subscriptions — fetch all, then enrich with topicDetails
      print(
          '🔄 [SyncedLibrary] Syncing subscribed channels...');
      List<YoutubeArtistChannel> allSubscriptions = [];
      List<YoutubeArtistChannel> musicArtists = [];
      try {
        final rawSubs = await _syncService.fetchSubscribedChannels();
        print(
            '🔄 [SyncedLibrary] Enriching ${rawSubs.length} subscriptions with topic details...');
        allSubscriptions = await _syncService.enrichWithTopicDetails(rawSubs);
        musicArtists =
            allSubscriptions.where((c) => c.isMusicArtist).toList();
        print(
            '🟢 [SyncedLibrary] Subscriptions synced: ${allSubscriptions.length} total, '
            '${musicArtists.length} music artists identified');
      } catch (e) {
        print('⚠️ [SyncedLibrary] Subscription sync failed: $e');
      }

      // 5. Cache everything in Hive
      await box.put(
          _keyPlaylists,
          json.encode(playlists.map((p) => p.toJson()).toList()));
      await box.put(
          _keyLikedSongs,
          json.encode(likedSongs.map((t) => _trackToJson(t)).toList()));
      await box.put(
          _keyAllSubscriptions,
          json.encode(
              allSubscriptions.map((c) => c.toJson()).toList()));
      await box.put(
          _keyMusicArtists,
          json.encode(musicArtists.map((c) => c.toJson()).toList()));

      state = SyncedLibraryState(
        playlists: playlists,
        playlistTracks: playlistTracks,
        likedSongs: likedSongs,
        allSubscriptions: allSubscriptions,
        musicArtists: musicArtists,
        isLoading: false,
      );
      print('🟢 [SyncedLibrary] Sync complete!');
    } catch (e) {
      print('🔴 [SyncedLibraryNotifier] Error syncing library: $e');
      state = state.copyWith(isLoading: false, syncError: e.toString());
    }
  }

  // ── Cache Clear ──────────────────────────────────────────────────────────

  Future<void> clearCache() async {
    final box = Hive.box('synced_library');
    await box.delete(_keyPlaylists);
    await box.delete(_keyLikedSongs);
    await box.delete(_keyAllSubscriptions);
    await box.delete(_keyMusicArtists);
    for (final p in state.playlists) {
      await box.delete(_keyPlaylistTracks(p.id));
    }
    state = const SyncedLibraryState();
  }

  // ── Serialization Helpers ─────────────────────────────────────────────────

  Map<String, dynamic> _trackToJson(YoutubeTrack t) {
    return {
      'id': t.id,
      'title': t.title,
      'artistName': t.artistName,
      'artistId': t.artistId,
      'albumName': t.albumName,
      'albumId': t.albumId,
      'artworkUrl': t.artworkUrl,
      'durationMs': t.duration?.inMilliseconds,
      'isMusicVideo': t.isMusicVideo,
    };
  }

  YoutubeTrack _trackFromJson(Map<String, dynamic> json) {
    final durationMs = json['durationMs'] as int?;
    return YoutubeTrack(
      id: json['id'] as String,
      title: json['title'] as String,
      artistName: json['artistName'] as String,
      artistId: json['artistId'] as String?,
      albumName: json['albumName'] as String?,
      albumId: json['albumId'] as String?,
      artworkUrl: json['artworkUrl'] as String?,
      duration: durationMs != null ? Duration(milliseconds: durationMs) : null,
      isMusicVideo: json['isMusicVideo'] as bool? ?? false,
    );
  }
}

final syncedLibraryProvider =
    StateNotifierProvider<SyncedLibraryNotifier, SyncedLibraryState>((ref) {
  final syncService = ref.watch(youtubeSyncServiceProvider);
  return SyncedLibraryNotifier(syncService, ref);
});
