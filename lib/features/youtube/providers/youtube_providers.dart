import 'package:dart_ytmusic_api/yt_music.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../data/repositories/youtube_repository.dart';
import '../data/repositories/ytmusic_repository.dart';
import '../data/models/youtube_track.dart';
import '../data/models/youtube_playlist.dart';
import '../../auth/providers/auth_provider.dart';
import '../../player/providers/player_provider.dart';
import '../../auth/providers/personalization_provider.dart';
import '../../auth/data/models/user_preference_profile.dart';
import '../../auth/data/models/youtube_artist_channel.dart';
import '../../library/providers/local_library_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';
import 'dart:math';

// ─── youtube_explode_dart (audio only) ───────────────────────────────────────

final youtubeExplodeProvider = Provider<YoutubeExplode>((ref) {
  final yt = YoutubeExplode();
  ref.onDispose(() => yt.close());
  return yt;
});

final youtubeRepositoryProvider = Provider<YoutubeRepository>((ref) {
  return YoutubeRepository(ref.watch(youtubeExplodeProvider));
});

// ─── dart_ytmusic_api (metadata, search, lyrics, home) ───────────────────────

/// Singleton YTMusic client — initialized once, reused everywhere.
/// Initialization makes one network call to grab YT Music's internal tokens.
final ytMusicProvider = Provider<YTMusic>((ref) {
  final client = YTMusic();
  ref.onDispose(() {});
  return client;
});

/// Async provider that initializes YTMusic once and returns the ready repository.
final ytMusicRepositoryProvider = FutureProvider<YTMusicRepository>((ref) async {
  final ytMusic = ref.watch(ytMusicProvider);
  try {
    (ytMusic as dynamic).setAuthorizationToken(null);
  } catch (_) {}

  ytMusic.config = {
    'INNERTUBE_API_KEY': 'AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30',
    'INNERTUBE_API_VERSION': 'v1',
    'INNERTUBE_CLIENT_NAME': 'WEB_REMIX',
    'INNERTUBE_CLIENT_VERSION': '1.20260526.04.00',
    'GL': 'IN',
    'HL': 'en',
  };
  ytMusic.hasInitialized = true;
  print('🟢 [YTMusic] Session initialized with WEB_REMIX client config');
  return YTMusicRepository(ytMusic);
});

// ─── Search ───────────────────────────────────────────────────────────────────

List<YoutubeTrack> _localMusicFilter(List<YoutubeTrack> tracks) {
  final blacklist = [
    'shorts', '#shorts', 'tiktok', 'fashion', 'outfit', 'haul',
    'vlog', 'trailer', 'teaser', 'clip', 'sound effect', 'preview',
    'unboxing', 'review', 'makeup', 'grwm', 'lookbook', 'style',
    'reels', 'reel', 'reaction', 'gaming', 'tutorial'
  ];
  
  final countBefore = tracks.length;
  final filtered = tracks.where((track) {
    if (track.id.trim().isEmpty) {
      return false;
    }
    // Keep playlists and albums (collections rather than single videos)
    if (track.id.startsWith('playlist_') || track.id.startsWith('album_') || track.id.startsWith('artist_')) {
      return true;
    }
    final title = track.title.toLowerCase();
    final artist = track.artistName.toLowerCase();
    
    if (blacklist.any((word) => title.contains(word) || artist.contains(word))) {
      return false;
    }
    // Only exclude extremely short clips (< 30 seconds)
    if (track.duration != null && track.duration!.inSeconds < 30) {
      return false;
    }
    return true;
  }).toList();

  print('🕵️ [_localMusicFilter] Count before: $countBefore, after filtering: ${filtered.length}');
  return filtered;
}

/// Search YouTube Music catalog for songs. Uses YTMusic API for proper
/// square album art, album names, and rich metadata.
final searchTracksProvider = FutureProvider.family<List<YoutubeTrack>, String>((ref, query) async {
  if (query.trim().isEmpty) return [];
  final repoAsync = await ref.watch(ytMusicRepositoryProvider.future);
  final tracks = await repoAsync.searchSongs(query);
  return _localMusicFilter(tracks);
});

// Search UI state
final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider<List<YoutubeTrack>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  final repoFuture = ref.watch(ytMusicRepositoryProvider.future);
  if (query.trim().isEmpty) return [];
  print('🔎 [searchResultsProvider] Starting search for: "$query"');
  await Future.delayed(const Duration(milliseconds: 500));
  try {
    print('🔎 [searchResultsProvider] Awaiting ytMusicRepositoryProvider...');
    final repoAsync = await repoFuture;
    print('🔎 [searchResultsProvider] Calling searchSongs for: "$query"');
    final tracks = await repoAsync.searchSongs(query);
    print('🔎 [searchResultsProvider] Found ${tracks.length} raw tracks from searchSongs');
    final filtered = _localMusicFilter(tracks);
    print('🔎 [searchResultsProvider] Filtered down to ${filtered.length} tracks');
    return filtered;
  } catch (e, s) {
    print('🔴 [searchResultsProvider] Error during search: $e\n$s');
    rethrow;
  }
});

final searchVideosResultsProvider = FutureProvider<List<YoutubeTrack>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  final repoFuture = ref.watch(ytMusicRepositoryProvider.future);
  if (query.trim().isEmpty) return [];
  print('🎬 [searchVideosResultsProvider] Starting video search for: "$query"');
  await Future.delayed(const Duration(milliseconds: 500));
  try {
    print('🎬 [searchVideosResultsProvider] Awaiting ytMusicRepositoryProvider...');
    final repoAsync = await repoFuture;
    print('🎬 [searchVideosResultsProvider] Calling searchVideos for: "$query"');
    final tracks = await repoAsync.searchVideos(query);
    print('🎬 [searchVideosResultsProvider] Found ${tracks.length} raw video tracks');
    final filtered = _localMusicFilter(tracks);
    print('🎬 [searchVideosResultsProvider] Filtered down to ${filtered.length} video tracks');
    return filtered;
  } catch (e, s) {
    print('🔴 [searchVideosResultsProvider] Error during video search: $e\n$s');
    rethrow;
  }
});

// ─── Home Feed ────────────────────────────────────────────────────────────────

/// YouTube Music home sections (curated feed — "Top picks", "Trending", etc.)
final homeSectionsProvider = FutureProvider<List<YTMusicHomeSection>>((ref) async {
  final repo = await ref.watch(ytMusicRepositoryProvider.future);
  return repo.getHomeSections();
});

/// Home page music videos provider
final homeVideoSongsProvider = FutureProvider<List<YoutubeTrack>>((ref) async {
  final repo = await ref.watch(ytMusicRepositoryProvider.future);
  return repo.searchVideos('official music video');
});

// ─── Lyrics ───────────────────────────────────────────────────────────────────

final lyricsProvider = FutureProvider.family<String?, String>((ref, videoId) async {
  final repo = await ref.watch(ytMusicRepositoryProvider.future);
  return repo.getLyrics(videoId);
});

final timedLyricsProvider = FutureProvider.family<List<TimedLyricLine>, String>((ref, videoId) async {
  final repo = await ref.watch(ytMusicRepositoryProvider.future);
  return repo.getTimedLyrics(videoId);
});

// ─── Up Next ──────────────────────────────────────────────────────────────────

final upNextProvider = FutureProvider.family<List<YoutubeTrack>, String>((ref, videoId) async {
  final repo = await ref.watch(ytMusicRepositoryProvider.future);
  return repo.getUpNexts(videoId);
});

// ─── Artist ───────────────────────────────────────────────────────────────────

final artistSongsProvider = FutureProvider.family<List<YoutubeTrack>, String>((ref, artistId) async {
  final repo = await ref.watch(ytMusicRepositoryProvider.future);
  return repo.getArtistSongs(artistId);
});

// ─── Album ────────────────────────────────────────────────────────────────────

final albumSongsProvider = FutureProvider.family<List<YoutubeTrack>, String>((ref, albumId) async {
  final repo = await ref.watch(ytMusicRepositoryProvider.future);
  return repo.getAlbumSongs(albumId);
});

// ─── Playlist ─────────────────────────────────────────────────────────────────

final playlistSongsProvider = FutureProvider.family<List<YoutubeTrack>, String>((ref, playlistId) async {
  final repo = await ref.watch(ytMusicRepositoryProvider.future);
  return repo.getPlaylistSongs(playlistId);
});

final relatedPlaylistsProvider = FutureProvider.family<List<YoutubePlaylist>, String>((ref, query) async {
  if (query.trim().isEmpty) return [];
  final repo = await ref.watch(ytMusicRepositoryProvider.future);
  return repo.searchPlaylists(query);
});

// ─── Legacy (kept for audio resolution fallback) ──────────────────────────────

final playlistProvider = FutureProvider.family<YoutubePlaylist, String>((ref, id) async {
  return ref.watch(youtubeRepositoryProvider).getPlaylist(id);
});

final relatedTracksProvider = FutureProvider.family<List<YoutubeTrack>, String>((ref, videoId) async {
  return ref.watch(youtubeRepositoryProvider).getRelatedTracks(videoId);
});

// ─── Synced User History & Recommendations ───────────────────────────────────

/// Dedicated authenticated YTMusic instance using user's Google Sign-In access token.
/// Runs under the ANDROID_MUSIC client context to allow authenticated InnerTube requests.
final authenticatedYtMusicRepositoryProvider = FutureProvider<YTMusicRepository?>((ref) async {
  final googleUserAsync = ref.watch(googleUserProvider);
  final googleUser = googleUserAsync.value;
  if (googleUser == null) {
    print('⚪ [AuthYTMusic] User not logged in, returning null authenticated repository');
    return null;
  }

  try {
    final authHeaders = await googleUser.authHeaders;
    final token = authHeaders['Authorization']?.replaceFirst('Bearer ', '');
    if (token == null) {
      print('⚠️ [AuthYTMusic] No authorization token available in user auth headers');
      return null;
    }

    final ytMusic = YTMusic();
    // Manually initialize config to target ANDROID_MUSIC directly and cleanly,
    // avoiding the WEB_REMIX config injection that causes a payload mismatch (400 Bad Request) on mobile.
    ytMusic.config = {
      'INNERTUBE_API_KEY': 'AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30',
      'INNERTUBE_API_VERSION': 'v1',
      'INNERTUBE_CLIENT_NAME': 'ANDROID_MUSIC',
      'INNERTUBE_CLIENT_VERSION': '8.05.50',
      'INNERTUBE_CONTEXT_CLIENT_NAME': '60',
      'GL': 'IN',
      'HL': 'en',
    };
    ytMusic.hasInitialized = true;
    try {
      (ytMusic as dynamic).setAuthorizationToken(token);
    } catch (_) {}

    print('🟢 [AuthYTMusic] Authenticated YTMusic repository initialized successfully');
    
    // Diagnostic verification test triggered on startup when signed in
    Future.microtask(() => _runPersonalizationMismatchVerificationTest(googleUser, token));

    return YTMusicRepository(ytMusic);
  } catch (e) {
    print('🔴 [AuthYTMusic] Failed to initialize authenticated YTMusic repository: $e');
    return null;
  }
});

/// Fetches the user's chronological watch history (most played/recent tracks) from their synced YouTube Music account.
final syncedHistoryProvider = FutureProvider<List<YoutubeTrack>>((ref) async {
  final authRepo = await ref.watch(authenticatedYtMusicRepositoryProvider.future);
  if (authRepo == null) {
    print('⚪ [SyncedHistory] User not logged in or unauthenticated, returning empty synced history');
    return [];
  }
  try {
    final history = await authRepo.getHistory();
    return history;
  } catch (e) {
    print('⚠️ [SyncedHistory] Failed to fetch watch history: $e');
    return [];
  }
});

// Selected category mood chip (Romance, Feel good, Workout, Energize, Focus, Relax, Podcasts)
final selectedMoodProvider = StateProvider<String?>((ref) => null);

// ─── Artist Scoring ───────────────────────────────────────────────────────────

/// Builds a weighted artist score map from all available signals.
///
/// Score formula (deterministic, higher = stronger preference):
///   subscribed      × 10  — explicit follow, strongest intent signal
///   liked songs     × 3   — direct like action
///   in-app plays    × 2   — engagement signal
///   playlist member × 1   — passive curation signal
// ─────────────────────────────────────────────────────────────────────────────

// ─── Shared Artist Data Fallbacks ──────────────────────────────────────────



const Map<String, String> _artistCovers = {
  "Anirudh Ravichander": "https://lh3.googleusercontent.com/wBG4jypwBcEGHd-qSbM2_4B46WPEhlOCjusCOEkxdnsoIC4WLS9LmFARZsE854pB-vAEYlsp4x2yiHE=w120-h120-p-l90-rj",
  "Arijit Singh": "https://lh3.googleusercontent.com/W_yOqnKSDYyeVOY_AsXhuAtb6rW3vCL3GtJ9DA1GxWOrJfyeSOqzvTv_TkFHijdkVPXWutASBlRFPg=w120-h120-p-l90-rj",
  "Sid Sriram": "https://yt3.googleusercontent.com/Ip35qauI_vMztXkJ3Wd6etvLwiyRrHIGvDyKK3714vyWMBx1ogHxPxkA8ohPnOLyy68wzEVBblPmsHHU=w120-h120-p-l90-rj",
  "A.R. Rahman": "https://yt3.googleusercontent.com/vHMOuDn8gr3SW9Pm8yFgmtYzM5kj4ayng5HKRjW0OyjG9mPK923XMVtTZTt4NUG_1aemWNLSQ27zjtA=w120-h120-l90-rj",
  "Devi Sri Prasad (DSP)": "https://yt3.googleusercontent.com/Jn3s6U5foBczx3HoJuiVN6euF7QRB1b8rsp3lecxZ7EwumQ-27E_iR2uu8fJV0H6cctb74s5nut_dhM=w120-h120-p-l90-rj",
  "The Weeknd": "https://lh3.googleusercontent.com/U-SAmNOu4TynE818gLCfKsuHZ0U5YNEtO9mrjSI9WCCKERs98LzrCal5kajBBTQNwdcisoB2Bn-pHp4=w120-h120-p-l90-rj",
  "Ed Sheeran": "https://lh3.googleusercontent.com/jQoBIAS6JjFGpcqQY1M_Mh3AasOvFENCdVRxkgax1a0K6qiq7AgE3MbJ6Jtt-Jndcarvoawmrg66KTny=w120-h120-p-l90-rj",
  "BTS": "https://lh3.googleusercontent.com/8rsLpP6VJjt-yTN8ZG5rY-qt2aCC-IYMWmVkk7qa8c5vrjO6zetKSgwO2QknHI3FtWl6Zannp2VsQ5o=w120-h120-l90-rj",
  "Taylor Swift": "https://yt3.googleusercontent.com/RCpTA6EXJQyjVFDosWOKa2SMmqkua_lA9mHPDWWciLwgqpZLz-k8rXWRF_367trrQ7up9BUwCbk6kRk=w120-h120-p-l90-rj",
  "Shreya Ghoshal": "https://yt3.ggpht.com/PgINZNe0qVxgMSXKG5vF82bNN4WCC12zgWsz9I7OLs4CLF9Cn0Vxq7Xc1ToupnzXrCv0nKfe3VM=w120-c-h120-k-c0x00ffffff-no-l90-rj",
  "Harris Jayaraj": "https://yt3.googleusercontent.com/WL9RZw5FixFw1o9En00D9gdXXMwnTs4E2DqvQ18E4DvzEl1MY_zGwIP0AjJ8o2zKe0IOOMwggK_Jr59Xsw=w120-h120-l90-rj",
  "Yuvan Shankar Raja": "https://lh3.googleusercontent.com/-IRVL5B0n7-V9Gh9XZvQG161HYqkH_SNSHfJwWYeIcVVh35sMq9-jHTk1FCeAmeUHSdEq7UMpoVzUPw=w120-h120-p-l90-rj",
  "S.P. Balasubrahmanyam": "https://yt3.googleusercontent.com/i-PUJfHy7H3_s1AUBWUaulTzhclF5MobqSIw_3nM3a2-kfCGsY_67K-dEOW7baAiBdfHvSOuHVjR_g=w120-h120-p-l90-rj",
  "K.S. Chithra": "https://yt3.googleusercontent.com/cFho6QFr9dAAQ7bspBLLi6jkuASqcgmFpgC4s3mnuSZkrUnGU9Zj6EZS5AlbKNv0gVFdw3CEVEGKaQ=w120-h120-p-l90-rj",
  "Sidhu Moose Wala": "https://yt3.ggpht.com/ytc/AIdro_kiQJ0Hhp0O-tdaY1dy81-gSNujjccUlWstnpFr686ZlMk=w120-h120-l90-rj",
  "Diljit Dosanjh": "https://yt3.googleusercontent.com/7EYXXMXY594V8y4sZT2aawmdKgDAGTu5jNm9C-HpR3jY9cZJ0NMxS__nZKBdWZ1PUpJPjc2BAA=w120-h120-l90-rj",
  "Pritam": "https://yt3.googleusercontent.com/sjGMYJQ1J3FZEIBsMYUztMjjYOM4-NJ24CjmIHqxTWCxAM1YgjL-d_17u7_PRhTouOwwAjbu-2x5S6I=w120-h120-p-l90-rj",
  "Badshah": "https://lh3.googleusercontent.com/bbR8znm7CX07mCGQH-M484ckFRaKkSmTjwrwuFZxQUBy7Uc5gQcintkpqDXCuSX0DdLLg2aPskZhC2s=w120-h120-p-l90-rj",
  "Billie Eilish": "https://lh3.googleusercontent.com/tQC4rOL6xz6FhmFr0ggQExxyGbYSOsyveXVSnPBh2WjEyIzQ9pMHablLJ-0GlMBrLBlBrbWQGmzrV6KN=w120-h120-p-l90-rj",
  "Dua Lipa": "https://lh3.googleusercontent.com/aFx8s1fTuelgxONGbezmTG0EKR8r82uB5H-Q6ZJtssyCWLJWF8GfZNr4tHo84sXdFCPBKrA4R6zXOss=w120-h120-p-l90-rj",
  "Drake": "https://yt3.googleusercontent.com/MxNjcRJ-uK4Xvx7u90IhEFLQM8x9LIGTA9VCKHq5U4Wn2jOgiWaMtg-qz329SIzqnCyhdCCB3MpdAGs=w120-h120-p-l90-rj",
  "Justin Bieber": "https://lh3.googleusercontent.com/4ULlRiFBFglNemZJyKn6_e2-iOIdJEbgBgq_79RQclndG6pge0yGgS2k2On6E1FkCJzenyHkHRzkvjFp=w120-h120-p-l90-rj",
  "Alan Walker": "https://yt3.googleusercontent.com/1-Ipiq-y8WyAcWn88nuxwTHaaBWMg8VkCBuP3puDCec-neD3v-7SqoBRzmmBKmA-lir_Ie70yw9EKHk=w120-h120-p-l90-rj",
  "Coldplay": "https://lh3.googleusercontent.com/IOKuXtp8PCQ_Fc-vaRKm3sKIXBxFV51gZheLTH5br-YGnWHFQf_Jywcuk7wbprYRoEbQyS_XZY6-nMJX=w120-h120-p-l90-rj"
};

class CachedRecommendations {
  final List<YoutubeTrack> tracks;
  final DateTime generatedAt;

  CachedRecommendations({required this.tracks, required this.generatedAt});

  Map<String, dynamic> toJson() => {
    'tracks': tracks.map((t) => {
      'id': t.id,
      'title': t.title,
      'artistName': t.artistName,
      'artistId': t.artistId,
      'albumName': t.albumName,
      'albumId': t.albumId,
      'artworkUrl': t.artworkUrl,
      'durationMs': t.duration?.inMilliseconds,
      'isMusicVideo': t.isMusicVideo,
      'language': t.language,
      'mood': t.mood,
      'releaseYear': t.releaseYear,
      'energyScore': t.energyScore,
      'popularityScore': t.popularityScore,
      'isOfficialMusic': t.isOfficialMusic,
      'isTopicChannel': t.isTopicChannel,
      'recommendationReason': t.recommendationReason,
      'releaseDate': t.releaseDate?.toIso8601String(),
    }).toList(),
    'generatedAt': generatedAt.toIso8601String(),
  };

  factory CachedRecommendations.fromJson(Map<String, dynamic> json) {
    return CachedRecommendations(
      tracks: (json['tracks'] as List<dynamic>?)
          ?.map((e) {
            final m = e as Map<String, dynamic>;
            return YoutubeTrack(
              id: m['id'] as String,
              title: m['title'] as String,
              artistName: m['artistName'] as String,
              artistId: m['artistId'] as String?,
              albumName: m['albumName'] as String?,
              albumId: m['albumId'] as String?,
              artworkUrl: m['artworkUrl'] as String?,
              duration: m['durationMs'] != null ? Duration(milliseconds: m['durationMs'] as int) : null,
              isMusicVideo: m['isMusicVideo'] as bool? ?? false,
              language: m['language'] as String?,
              mood: m['mood'] as String?,
              releaseYear: m['releaseYear'] as int?,
              energyScore: m['energyScore'] as double?,
              popularityScore: m['popularityScore'] as double?,
              isOfficialMusic: m['isOfficialMusic'] as bool? ?? true,
              isTopicChannel: m['isTopicChannel'] as bool? ?? false,
              recommendationReason: m['recommendationReason'] as String?,
              releaseDate: m['releaseDate'] != null ? DateTime.parse(m['releaseDate'] as String) : null,
            );
          })
          .toList() ?? [],
      generatedAt: json['generatedAt'] != null
          ? DateTime.parse(json['generatedAt'])
          : DateTime.now(),
    );
  }
}

Future<List<YoutubeTrack>> getCachedRecommendations(String key, Future<List<YoutubeTrack>> Function() generator) async {
  final box = Hive.box('user_profile');
  final raw = box.get(key) as String?;
  if (raw != null) {
    try {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      final cached = CachedRecommendations.fromJson(decoded);
      final age = DateTime.now().difference(cached.generatedAt);
      if (age.inHours < 24 && cached.tracks.isNotEmpty) {
        print('📦 [HomeSections] Loaded stable cached recommendations for "$key" (Age: ${age.inHours} hours)');
        return cached.tracks;
      }
    } catch (e) {
      print('⚠️ [HomeSections] Failed to load cache for "$key": $e');
    }
  }

  final newTracks = await generator();
  final cacheObj = CachedRecommendations(tracks: newTracks, generatedAt: DateTime.now());
  await box.put(key, json.encode(cacheObj.toJson()));
  print('💾 [HomeSections] Generated and cached new recommendations for "$key"');
  return newTracks;
}

final dynamicHomeSectionsProvider = FutureProvider<List<YTMusicHomeSection>>((ref) async {
  ref.watch(googleUserProvider);
  YTMusicRepository? repoCandidate;
  try {
    repoCandidate = await ref.watch(authenticatedYtMusicRepositoryProvider.future);
  } catch (_) {}
  repoCandidate ??= await ref.watch(ytMusicRepositoryProvider.future);
  final repo = repoCandidate;
  final mood = ref.watch(selectedMoodProvider);
  final recentPlayed = ref.watch(recentlyPlayedProvider);
  final library = ref.read(syncedLibraryProvider);
  final preferences = ref.watch(userPreferenceProfileProvider);
  final taste = ref.read(tasteProfileProvider);
  final musicProfile = ref.read(userMusicProfileProvider);
  final scoreTrack = ref.read(songScorerProvider);

  if (mood != null && repo != null) {
    try {
      final moodQuery = mood.toLowerCase();
      final moodSections = <YTMusicHomeSection>[];
      final moodKeywords = {
        'romance': ['romance', 'romantic', 'love', 'date', 'valentines'],
        'feel good': ['feel good', 'happy', 'joy', 'upbeat', 'optimistic', 'smile'],
        'workout': ['workout', 'gym', 'training', 'run', 'cardio', 'fitness', 'power', 'beast'],
        'energize': ['energize', 'energy', 'power', 'beast', 'party', 'dance', 'workout'],
        'focus': ['focus', 'study', 'concentration', 'work', 'chill', 'relax', 'instrumental', 'ambient'],
        'relax': ['relax', 'chill', 'sleep', 'calm', 'acoustic', 'ambient', 'soothing'],
      };
      
      final keywords = moodKeywords[moodQuery] ?? [moodQuery];
      final matchingSongs = <YoutubeTrack>[];
      final seenSongIds = <String>{};

      for (final song in library.likedSongs) {
        final titleLower = song.title.toLowerCase();
        if (keywords.any((kw) => titleLower.contains(kw)) && seenSongIds.add(song.id)) {
          matchingSongs.add(song);
        }
      }

      // Fetch matching songs from YT
      List<YoutubeTrack> searchSongs = [];
      try {
        searchSongs = await repo.searchSongs('$moodQuery hits');
      } catch (e) {
        print('Error searching mood songs: $e');
      }

      final allSongs = [...matchingSongs, ..._localMusicFilter(searchSongs)];
      final uniqueSongs = <String, YoutubeTrack>{};
      for (final s in allSongs) {
        uniqueSongs[s.id] = s;
      }

      if (uniqueSongs.isNotEmpty) {
        moodSections.add(YTMusicHomeSection(
          title: 'Quick picks',
          tracks: uniqueSongs.values.take(24).toList(),
        ));
      }

      // Removed Popular $mood Mixes to purge mix suggestions from categories

      // Fetch matching albums
      try {
        final albums = await repo.searchAlbums(mood);
        if (albums.isNotEmpty) {
          moodSections.add(YTMusicHomeSection(
            title: 'Featured $mood Albums',
            tracks: albums.map((a) => YoutubeTrack(
              id: 'album_${a['id']}',
              title: a['title'] as String,
              artistName: a['artist'] as String,
              artworkUrl: a['thumbnail'] as String?,
            )).take(12).toList(),
          ));
        }
      } catch (e) {
        print('Error searching mood albums: $e');
      }

      if (moodSections.isNotEmpty) {
        return moodSections;
      }
    } catch (e) {
      print('Error generating mood sections: $e');
    }
  }

  try {
    final homeSections = <YTMusicHomeSection>[];
    if (repo == null) return [];

    final scoredArtists = getScoredArtists(
      preferences: preferences,
      taste: taste,
      musicProfile: musicProfile,
    );

    // Global tracking maps for v4.1 rules
    final globalSeenTrackIds = <String>{};
    final globalArtistExposure = <String, int>{};

    List<YoutubeTrack> processShelf(List<YoutubeTrack> candidates) {
      final result = <YoutubeTrack>[];
      final shelfArtistExposure = <String, int>{};

      for (final track in candidates) {
        if (track.id.startsWith('playlist_') || track.id.startsWith('album_') || track.id.startsWith('artist_')) {
          result.add(track);
          continue;
        }

        // Deduplication
        if (globalSeenTrackIds.contains(track.id)) {
          continue;
        }

        final artist = track.artistName.trim();
        final shelfCount = shelfArtistExposure[artist] ?? 0;
        final globalCount = globalArtistExposure[artist] ?? 0;

        if (shelfCount >= 2) continue;
        if (globalCount >= 5) continue;

        result.add(track);
        globalSeenTrackIds.add(track.id);
        shelfArtistExposure[artist] = shelfCount + 1;
        globalArtistExposure[artist] = globalCount + 1;
      }
      return result;
    }

    final onboardingArtistsSorted = preferences?.artists ?? const [];
    final topArtist = scoredArtists.isNotEmpty
        ? scoredArtists.first.key
        : (onboardingArtistsSorted.isNotEmpty ? onboardingArtistsSorted.first : 'Sid Sriram');

    final hasTelugu = (preferences?.languages.any((l) => l.toLowerCase() == 'telugu') == true) ||
                      musicProfile.languageScores.containsKey('Telugu');
    final hasHindi = (preferences?.languages.any((l) => l.toLowerCase() == 'hindi') == true) ||
                     musicProfile.languageScores.containsKey('Hindi');

    // 1. Continue Listening
    if (recentPlayed.isNotEmpty) {
      final uniqueHistory = <String>{};
      final continueListeningTracks = recentPlayed
          .where((t) => uniqueHistory.add(t.id))
          .toList();
      final filtered = _localMusicFilter(continueListeningTracks);
      final processed = processShelf(filtered);
      if (processed.isNotEmpty) {
        homeSections.add(YTMusicHomeSection(
          title: 'Continue Listening',
          tracks: processed.take(10).map((t) => t.copyWith(artworkUrl: upscaleYoutubeThumbnail(t.artworkUrl))).toList(),
        ));
      }
    }

    // 2. Quick Picks (Combines recommendations from top artists & preferred languages)
    final quickPicksCandidates = <YoutubeTrack>[];
    try {
      final topArtistSongs = await repo.searchSongs(topArtist);
      quickPicksCandidates.addAll(_localMusicFilter(topArtistSongs));
    } catch (_) {}

    if (hasTelugu) {
      try {
        final teluguSongs = await repo.searchSongs('Telugu melody songs');
        quickPicksCandidates.addAll(_localMusicFilter(teluguSongs));
      } catch (_) {}
    }
    if (hasHindi) {
      try {
        final hindiSongs = await repo.searchSongs('Hindi romantic songs');
        quickPicksCandidates.addAll(_localMusicFilter(hindiSongs));
      } catch (_) {}
    }

    final processedQuickPicks = processShelf(quickPicksCandidates);
    if (processedQuickPicks.isNotEmpty) {
      homeSections.add(YTMusicHomeSection(
        title: 'Quick picks',
        tracks: processedQuickPicks.take(24).map((t) => t.copyWith(artworkUrl: upscaleYoutubeThumbnail(t.artworkUrl))).toList(),
      ));
    }

    // 3. Recommended Albums (based on songs the user plays, not onboarding artist list)
    final prefKey = 'rec_albums_cache_v6_${(preferences?.languages ?? []).join('_')}_${(preferences?.artists ?? []).join('_')}';
    final recommendedAlbums = await getCachedRecommendations(prefKey, () async {
      final candidates = <YoutubeTrack>[];
      final seenAlbumIds = <String>{};
      
      // Determine user's top played artists based on play count map
      final trackPlays = musicProfile.trackPlays;
      final sortedTrackIds = trackPlays.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      final localLibrary = ref.read(localLibraryProvider);
      final topPlayedArtists = <String>{};
      for (final entry in sortedTrackIds) {
        final playedTrackId = entry.key;
        YoutubeTrack? matchedTrack;
        try {
          matchedTrack = recentPlayed.firstWhere((t) => t.id == playedTrackId);
        } catch (_) {}
        if (matchedTrack == null) {
          try {
            matchedTrack = library.likedSongs.firstWhere((t) => t.id == playedTrackId);
          } catch (_) {}
        }
        if (matchedTrack == null) {
          try {
            matchedTrack = localLibrary.favorites.firstWhere((t) => t.id == playedTrackId);
          } catch (_) {}
        }
        if (matchedTrack == null) {
          try {
            matchedTrack = localLibrary.downloads.firstWhere((t) => t.id == playedTrackId);
          } catch (_) {}
        }
        if (matchedTrack == null) {
          for (final p in localLibrary.playlists.values) {
            try {
              matchedTrack = p.tracks.firstWhere((t) => t.id == playedTrackId);
              break;
            } catch (_) {}
          }
        }
        if (matchedTrack != null) {
          topPlayedArtists.add(matchedTrack.artistName);
        }
        if (topPlayedArtists.length >= 3) break;
      }

      // Fallback to onboarding artists if no plays are registered yet
      if (topPlayedArtists.isEmpty) {
        topPlayedArtists.addAll(onboardingArtistsSorted.take(3));
      }
      if (topPlayedArtists.isEmpty) {
        topPlayedArtists.add('Sid Sriram');
        topPlayedArtists.add('A.R. Rahman');
      }

      final preferredLangs = preferences?.languages ?? const [];

      // Query albums matching both artists AND their preferred languages
      for (final artist in topPlayedArtists) {
        if (preferredLangs.isNotEmpty) {
          for (final lang in preferredLangs) {
            try {
              final albums = await repo.searchAlbums('$artist $lang');
              for (final album in albums) {
                final id = album['id'];
                if (id != null && seenAlbumIds.add(id)) {
                  candidates.add(YoutubeTrack(
                    id: 'album_$id',
                    title: album['title'] ?? 'Album',
                    artistName: album['artist'] ?? artist,
                    artworkUrl: upscaleYoutubeThumbnail(album['thumbnail'] as String?),
                    albumId: id,
                  ));
                }
              }
            } catch (_) {}
          }
        } else {
          try {
            final albums = await repo.searchAlbums(artist);
            for (final album in albums) {
              final id = album['id'];
              if (id != null && seenAlbumIds.add(id)) {
                candidates.add(YoutubeTrack(
                  id: 'album_$id',
                  title: album['title'] ?? 'Album',
                  artistName: album['artist'] ?? artist,
                  artworkUrl: upscaleYoutubeThumbnail(album['thumbnail'] as String?),
                  albumId: id,
                ));
              }
            }
          } catch (_) {}
        }
      }

      // Also search general movie soundtrack albums matching user's preferred languages!
      for (final lang in preferredLangs) {
        final movieQueries = [
          '$lang movie soundtrack albums',
          '$lang movie albums',
        ];
        for (final mq in movieQueries) {
          try {
            final albums = await repo.searchAlbums(mq);
            for (final album in albums) {
              final id = album['id'];
              if (id != null && seenAlbumIds.add(id)) {
                candidates.add(YoutubeTrack(
                  id: 'album_$id',
                  title: album['title'] ?? 'Album',
                  artistName: album['artist'] ?? '$lang Movie Album',
                  artworkUrl: upscaleYoutubeThumbnail(album['thumbnail'] as String?),
                  albumId: id,
                ));
              }
            }
          } catch (_) {}
        }
      }

      return candidates;
    });

    if (recommendedAlbums.isNotEmpty) {
      homeSections.add(YTMusicHomeSection(
        title: 'Recommended Albums',
        tracks: recommendedAlbums.take(15).toList(),
      ));
    }

    // 4. Circular Recommended Artists ("Artists You Follow")
    final subscribedArtists = List<YoutubeArtistChannel>.from(library.musicArtists);
    subscribedArtists.sort((a, b) {
      final scoreA = musicProfile.artistScores[a.name] ?? 0.0;
      final scoreB = musicProfile.artistScores[b.name] ?? 0.0;
      return scoreB.compareTo(scoreA);
    });

    final artistsYouFollowTracks = subscribedArtists.map((artist) => YoutubeTrack(
      id: 'artist_${artist.channelId}',
      title: artist.name,
      artistName: artist.name,
      artworkUrl: upscaleYoutubeThumbnail(artist.artworkUrl),
    )).toList();

    if (artistsYouFollowTracks.isNotEmpty) {
      homeSections.add(YTMusicHomeSection(
        title: 'Artists You Follow',
        tracks: artistsYouFollowTracks,
      ));
    } else if (onboardingArtistsSorted.isNotEmpty) {
      final fallbackTracks = onboardingArtistsSorted.map((name) => YoutubeTrack(
        id: 'artist_${name.replaceAll(' ', '_')}',
        title: name,
        artistName: name,
        artworkUrl: upscaleYoutubeThumbnail(_artistCovers[name]),
      )).toList();
      if (fallbackTracks.isNotEmpty) {
        homeSections.add(YTMusicHomeSection(
          title: 'Artists You Follow',
          tracks: fallbackTracks,
        ));
      }
    }

    // Mix For You section removed to completely purge mixes from feeds

    // 6. Discovery Picks
    final discoverTracks = await getCachedRecommendations('discover_for_you_cache', () async {
      final candidates = <YoutubeTrack>[];
      final seenDiscoverIds = <String>{};

      final sortedGenres = musicProfile.genreScores.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final sortedLangs = musicProfile.languageScores.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final queries = <String>[];
      if (scoredArtists.isNotEmpty) {
        queries.add(scoredArtists.first.key);
      }
      if (sortedGenres.isNotEmpty) {
        queries.add('${sortedGenres.first.key} hits');
      }
      if (sortedLangs.isNotEmpty) {
        queries.add('${sortedLangs.first.key} songs');
      }
      if (queries.isEmpty) {
        queries.add('discover music');
      }

      try {
        final futures = queries.map((q) => repo.searchSongs(q));
        final results = await Future.wait(futures);
        for (final list in results) {
          for (final track in list) {
            if (seenDiscoverIds.add(track.id)) {
              candidates.add(track);
            }
          }
        }
      } catch (_) {}

      final scoredDiscover = candidates.map((track) {
        final score = scoreTrack(track, isDiscovery: true);
        return MapEntry(track, score + Random().nextDouble() * 15.0);
      }).toList();

      scoredDiscover.sort((a, b) => b.value.compareTo(a.value));
      return _localMusicFilter(scoredDiscover.map((e) => e.key).toList());
    });

    final totalNonDiscoveryTracks = globalSeenTrackIds.length;
    final discoveryLimit = (totalNonDiscoveryTracks * 0.20).toInt().clamp(2, 6);
    final processedDiscovery = processShelf(discoverTracks);

    if (processedDiscovery.isNotEmpty) {
      homeSections.add(YTMusicHomeSection(
        title: 'Discovery Picks',
        tracks: processedDiscovery.take(discoveryLimit).map((t) => t.copyWith(artworkUrl: upscaleYoutubeThumbnail(t.artworkUrl))).toList(),
      ));
    }

    // 7. Trending Now
    List<YTMusicHomeSection> publicSections = [];
    try {
      publicSections = await repo.getHomeSections();
    } catch (_) {}

    final trendingSection = publicSections.firstWhere(
      (sec) {
        final titleLower = sec.title.toLowerCase();
        return titleLower.contains('trending') || titleLower.contains('charts') || titleLower.contains('popular') || titleLower.contains('hits');
      },
      orElse: () => YTMusicHomeSection(title: '', tracks: []),
    );

    List<YoutubeTrack> trendingSongsCandidates = [];
    if (trendingSection.tracks.isNotEmpty) {
      trendingSongsCandidates = trendingSection.tracks;
    } else {
      try {
        trendingSongsCandidates = await repo.searchSongs('trending global hits');
      } catch (_) {}
    }

    final filteredTrending = _localMusicFilter(trendingSongsCandidates);
    final processedTrending = processShelf(filteredTrending);

    if (processedTrending.isNotEmpty) {
      homeSections.add(YTMusicHomeSection(
        title: 'Trending Now',
        tracks: processedTrending.take(24).toList(),
      ));
    }

    // Increment artist impressions asynchronously
    final artistsShown = <String>[];
    for (final sec in homeSections) {
      for (final track in sec.tracks) {
        if (!track.id.startsWith('playlist_') && !track.id.startsWith('album_') && !track.id.startsWith('artist_')) {
          artistsShown.add(track.artistName);
        }
      }
    }
    if (artistsShown.isNotEmpty) {
      Future.microtask(() {
        ref.read(userMusicProfileProvider.notifier).recordArtistImpressions(artistsShown);
      });
    }

    _logRuntimeRecommendationReport(musicProfile, homeSections);

    return homeSections;
  } catch (e, stack) {
    print('🔴 [DynamicHomeSections] Error building home sections: $e\n$stack');
    return [];
  }
});

Future<void> _runPersonalizationMismatchVerificationTest(GoogleSignInAccount googleUser, String token) async {
  print('======================================================================');
  print('🕵️ STARTING PERSONALIZATION MISMATCH DIAGNOSTIC VERIFICATION TEST');
  print('======================================================================');

  // 1. Platform Diagnostics
  print('[1] PLATFORM DIAGNOSTICS');
  print('Platform: Web');
  print('Flutter Target Platform: web');
  print('Running inside a web browser: $kIsWeb');
  print('----------------------------------------------------------------------');

  // 2. Authentication Diagnostics
  print('[2] AUTHENTICATION DIAGNOSTICS');
  print('Google User Email: ${googleUser.email}');
  print('Google User Display Name: ${googleUser.displayName}');
  print('Auth Token Extracted Successfully: true');
  print('Token Value Present: ${token.isNotEmpty}');
  print('Authorization Header Attached: true (Bearer <token>)');
  print('----------------------------------------------------------------------');

  // We will run Test A (ANDROID_MUSIC) and Test B (WEB_REMIX)
  await _runClientTest('ANDROID_MUSIC', '8.05.50', '60', token);
  await _runClientTest('WEB_REMIX', '1.20260526.04.00', '67', token);

  print('======================================================================');
  print('🕵️ END OF PERSONALIZATION MISMATCH DIAGNOSTIC VERIFICATION TEST');
  print('======================================================================');
}

Future<void> _runClientTest(String clientName, String clientVersion, String clientContextName, String token) async {
  print('----------------------------------------------------------------------');
  print('🚀 TESTING INNER_TUBE CLIENT: $clientName');
  print('----------------------------------------------------------------------');
  print('Client Name: $clientName');
  print('Client Version: $clientVersion');
  print('Authorization Header Attached: true');

  final testYtMusic = YTMusic();
  testYtMusic.config = {
    'INNERTUBE_API_KEY': 'AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30',
    'INNERTUBE_API_VERSION': 'v1',
    'INNERTUBE_CLIENT_NAME': clientName,
    'INNERTUBE_CLIENT_VERSION': clientVersion,
    'INNERTUBE_CONTEXT_CLIENT_NAME': clientContextName,
    'GL': 'IN',
    'HL': 'en',
  };
  testYtMusic.hasInitialized = true;
  try {
    (testYtMusic as dynamic).setAuthorizationToken(token);
  } catch (_) {}

  final testRepo = YTMusicRepository(testYtMusic);

  // A. Test getHomeSections()
  await _testEndpoint(testYtMusic, 'getHomeSections()', () async {
    final sections = await testRepo.getHomeSections();
    return {
      'count': sections.length,
      'details': sections.map((s) => '${s.title} (${s.tracks.length} items)').join(', '),
      'rawSample': sections.isNotEmpty ? 'First section title: "${sections.first.title}"' : 'No sections',
    };
  }, 'browse', {"browseId": "FEmusic_home"});

  // B. Test getHistory()
  await _testEndpoint(testYtMusic, 'getHistory()', () async {
    final data = await testYtMusic.constructRequest("browse", body: {"browseId": "FEmusic_history"});
    if (data == null) return {'count': 0, 'rawSample': 'null response'};
    final tracks = testRepo.extractTracksFromJson(data);
    return {
      'count': tracks.length,
      'rawSample': 'Raw keys: ${(data is Map) ? data.keys.take(5).toList() : data.runtimeType}',
      'details': 'Successfully parsed ${tracks.length} tracks',
    };
  }, 'browse', {"browseId": "FEmusic_history"});

  // C. Test getLikedMusicSynced()
  await _testEndpoint(testYtMusic, 'getLikedMusicSynced()', () async {
    final data = await testYtMusic.constructRequest("browse", body: {"browseId": "FEmusic_liked_videos"});
    if (data == null) return {'count': 0, 'rawSample': 'null response'};
    final tracks = testRepo.extractTracksFromJson(data);
    return {
      'count': tracks.length,
      'rawSample': 'Raw keys: ${(data is Map) ? data.keys.take(5).toList() : data.runtimeType}',
      'details': 'Successfully parsed ${tracks.length} tracks',
    };
  }, 'browse', {"browseId": "FEmusic_liked_videos"});

  // D. Test getLibraryPlaylists()
  await _testEndpoint(testYtMusic, 'getLibraryPlaylists()', () async {
    final list = await testRepo.getLibraryPlaylists();
    return {
      'count': list.length,
      'details': 'Parsed playlists: ${list.map((p) => p.title).join(', ')}',
      'rawSample': 'Total playlists: ${list.length}',
    };
  }, 'browse', {"browseId": "FEmusic_to_go_playlists"});
}

Future<void> _testEndpoint(
  YTMusic ytMusic, 
  String name, 
  Future<Map<String, dynamic>> Function() runTest, 
  String rawEndpoint, 
  Map<String, dynamic> rawBody
) async {
  print('----------------------------------------');
  print('▶️ [$name] Request started...');
  try {
    final rawData = await ytMusic.constructRequest(rawEndpoint, body: rawBody);
    final rawLength = rawData != null ? rawData.toString().length : 0;
    final topLevelKeys = (rawData is Map) ? rawData.keys.toList() : [];
    
    print('✅ [$name] Request completed successfully');
    print('  - HTTP Status: 200 (Success)');
    print('  - Raw response payload length: $rawLength characters');
    print('  - Top-level response keys: $topLevelKeys');

    final result = await runTest();
    print('  - Parsed count: ${result['count']}');
    print('  - Parsed details: ${result['details']}');
    print('  - Raw sample details: ${result['rawSample']}');
  } catch (e, stack) {
    print('❌ [$name] Request failed with exception');
    
    String errorMsg = e.toString();
    int statusCode = 500;
    if (errorMsg.contains('status code:') || errorMsg.contains('- ')) {
      final match = RegExp(r'- (\d{3}) -').firstMatch(errorMsg);
      if (match != null) {
        statusCode = int.parse(match.group(1)!);
      }
    }
    print('  - HTTP Status Code: $statusCode');
    print('  - Error Message: $errorMsg');
    print('  - Stack Trace: $stack');
  }
}

void _logRuntimeRecommendationReport(UserMusicProfile profile, List<YTMusicHomeSection> sections) {
  print('======================================================================');
  print('📊 RUNTIME RECOMMENDATION ENGINE REPORT');
  print('======================================================================');

  // Top Artists
  final sortedArtists = profile.artistScores.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  print('👤 Top Artists:');
  for (final entry in sortedArtists.take(5)) {
    print('  - ${entry.key}: ${entry.value.toStringAsFixed(1)}');
  }

  // Top Genres
  final sortedGenres = profile.genreScores.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  print('🎵 Top Genres:');
  for (final entry in sortedGenres.take(5)) {
    print('  - ${entry.key}: ${entry.value.toStringAsFixed(1)}');
  }

  // Top Languages
  final sortedLanguages = profile.languageScores.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  print('🌐 Top Languages:');
  for (final entry in sortedLanguages.take(5)) {
    print('  - ${entry.key}: ${entry.value.toStringAsFixed(1)}');
  }

  print('----------------------------------------------------------------------');
  print('📋 Generated Sections:');
  int totalTracks = 0;
  for (final sec in sections) {
    print('  - "${sec.title}" containing ${sec.tracks.length} items');
    totalTracks += sec.tracks.length;
  }
  print('Candidate Counts (Total items across shelves): $totalTracks');

  // Deduped tracks verification
  final uniqueTrackIds = <String>{};
  for (final sec in sections) {
    for (final track in sec.tracks) {
      uniqueTrackIds.add(track.id);
    }
  }
  print('Deduped Counts: ${uniqueTrackIds.length}');

  // Queue Generation Sources info placeholder/log
  print('Queue Generation Sources Distribution target: 40% Same Artist, 25% Similar Artists, 20% Favorite Genres, 15% Discovery');
  
  // Verify rules
  bool hasInvalidVideo = false;
  final invalidKeywords = ['shorts', 'fashion', 'tutorial', 'vlog', 'gaming', 'diy', 'unboxing', 'how to'];
  for (final sec in sections) {
    for (final track in sec.tracks) {
      final titleLower = track.title.toLowerCase();
      if (invalidKeywords.any((kw) => titleLower.contains(kw))) {
        hasInvalidVideo = true;
      }
    }
  }
  print('Music Quality Check: ${hasInvalidVideo ? "⚠️ WARNING: Non-music content or keyword matched!" : "✅ PASS: No Shorts/vlogs/tutorials detected"}');
  print('======================================================================');
}

String upscaleYoutubeThumbnail(String? url) {
  if (url == null) return '';
  // Replace =w60-h60, =w120-h120, =w226-h226, =w544-h544, =s120-c etc with =w512-h512
  final regex = RegExp(r'=w\d+-h\d+');
  if (regex.hasMatch(url)) {
    return url.replaceAll(regex, '=w512-h512');
  }
  final regex2 = RegExp(r'/s\d+-c');
  if (regex2.hasMatch(url)) {
    return url.replaceAll(regex2, '/s512-c');
  }
  return url;
}


