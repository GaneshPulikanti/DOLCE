import 'dart:convert';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../data/models/user_preference_profile.dart';
import '../../youtube/data/models/youtube_track.dart';
import '../../youtube/data/services/session_intelligence_service.dart';
import '../../youtube/data/services/artist_similarity_service.dart';
import '../../youtube/data/services/negative_learning_service.dart';
import '../../auth/providers/auth_provider.dart';

// ─── Preference Profile Provider ─────────────────────────────────────────────

class UserPreferenceProfileNotifier extends StateNotifier<UserPreferenceProfile?> {
  UserPreferenceProfileNotifier() : super(null) {
    _loadFromHive();
  }

  void _loadFromHive() {
    final box = Hive.box('user_profile');
    final raw = box.get('preferences') as String?;
    if (raw != null) {
      try {
        final decoded = json.decode(raw) as Map<String, dynamic>;
        state = UserPreferenceProfile.fromJson(decoded);
        print('🟢 [Preferences] Loaded user preference profile from Hive.');
      } catch (e) {
        print('🔴 [Preferences] Failed to decode user profile: $e');
      }
    }
  }

  Future<void> savePreferences(UserPreferenceProfile profile) async {
    final box = Hive.box('user_profile');
    final encoded = json.encode(profile.toJson());
    await box.put('preferences', encoded);
    state = profile;
    print('💾 [Preferences] Saved user preference profile to Hive.');
  }

  Future<void> clearPreferences() async {
    final box = Hive.box('user_profile');
    await box.delete('preferences');
    state = null;
    print('🧹 [Preferences] Cleared user preference profile.');
  }
}

final userPreferenceProfileProvider =
    StateNotifierProvider<UserPreferenceProfileNotifier, UserPreferenceProfile?>((ref) {
  return UserPreferenceProfileNotifier();
});

// ─── Taste Profile Provider ──────────────────────────────────────────────────

class TasteProfileNotifier extends StateNotifier<TasteProfile> {
  final Ref ref;
  TasteProfileNotifier(this.ref) : super(TasteProfile.empty()) {
    _loadFromHive();
  }

  String? _lastTrackId;

  void _loadFromHive() {
    final box = Hive.box('user_profile');
    final raw = box.get('taste_profile') as String?;
    if (raw != null) {
      try {
        final decoded = json.decode(raw) as Map<String, dynamic>;
        state = TasteProfile.fromJson(decoded);
        print('🟢 [TasteProfile] Loaded taste profile from Hive.');
      } catch (e) {
        print('🔴 [TasteProfile] Failed to decode taste profile: $e');
      }
    }
  }

  Future<void> _saveToHive(TasteProfile profile) async {
    final box = Hive.box('user_profile');
    final encoded = json.encode(profile.toJson());
    await box.put('taste_profile', encoded);
    state = profile;
  }

  // ─── Playback Event Tracking (Phase 2 & 9) ───

  Future<void> trackSongStart(YoutubeTrack track) async {
    final artist = track.artistName;
    final songId = track.id;

    final songPlays = Map<String, int>.from(state.songPlays);
    final artistPlays = Map<String, int>.from(state.artistPlays);

    // Replay logic (Phase 9)
    if (_lastTrackId == songId) {
      songPlays[songId] = (songPlays[songId] ?? 0) + 5; // +5 song affinity
      print('🎵 [TasteProfile] Replay detected! +5 song affinity for "$songId"');
    } else {
      songPlays[songId] = (songPlays[songId] ?? 0) + 1; // standard start
    }

    artistPlays[artist] = (artistPlays[artist] ?? 0) + 1;
    _lastTrackId = songId;

    final updated = state.copyWith(
      songPlays: songPlays,
      artistPlays: artistPlays,
      lastUpdated: DateTime.now(),
    );
    await _saveToHive(updated);
    
    // Also track in new UserMusicProfile with neutral completion rate (0.5)
    ref.read(userMusicProfileProvider.notifier).trackPlaybackEvent(track, 0.5);
    print('🎵 [TasteProfile] Track start recorded: "${track.title}" by "$artist"');
  }

  Future<void> trackSongComplete(YoutubeTrack track) async {
    final artist = track.artistName;
    final songId = track.id;
    
    final songPlays = Map<String, int>.from(state.songPlays);
    final artistPlays = Map<String, int>.from(state.artistPlays);
    
    songPlays[songId] = (songPlays[songId] ?? 0) + 1; // standard completion boost
    artistPlays[artist] = (artistPlays[artist] ?? 0) + 1; // standard completion boost

    final updated = state.copyWith(
      songPlays: songPlays,
      artistPlays: artistPlays,
      lastUpdated: DateTime.now(),
    );
    await _saveToHive(updated);

    // Also track in new UserMusicProfile with positive completion rate (1.0)
    ref.read(userMusicProfileProvider.notifier).trackPlaybackEvent(track, 1.0);
    print('🎵 [TasteProfile] Track complete recorded: +2 total plays/affinity for "$artist"');
  }

  Future<void> trackSongSkip(YoutubeTrack track, Duration elapsed, Duration total) async {
    final artist = track.artistName;
    final songId = track.id;

    final skips = Map<String, int>.from(state.skips);
    final songPlays = Map<String, int>.from(state.songPlays);
    final artistPlays = Map<String, int>.from(state.artistPlays);

    double completionRate = 0.0;
    if (total.inMilliseconds > 0) {
      completionRate = elapsed.inMilliseconds / total.inMilliseconds;
    }

    if (completionRate >= 0.90) {
      // Positive play signal (+1 more play to make it +2 total)
      songPlays[songId] = (songPlays[songId] ?? 0) + 1;
      artistPlays[artist] = (artistPlays[artist] ?? 0) + 1;
    } else if (completionRate < 0.30) {
      // Skip signal (<30%): deduct start play, increment skips/skipCount
      songPlays[songId] = max(0, (songPlays[songId] ?? 1) - 1);
      artistPlays[artist] = max(0, (artistPlays[artist] ?? 1) - 1);
      skips[songId] = (skips[songId] ?? 0) + 1;
      skips[artist] = (skips[artist] ?? 0) + 1;
    }

    final updated = state.copyWith(
      skips: skips,
      songPlays: songPlays,
      artistPlays: artistPlays,
      lastUpdated: DateTime.now(),
    );
    await _saveToHive(updated);

    // Also track in new UserMusicProfile
    ref.read(userMusicProfileProvider.notifier).trackPlaybackEvent(track, completionRate);
  }

  Future<void> trackSearch(String query, String? artistName) async {
    if (artistName == null || artistName.trim().isEmpty) return;
    final artist = artistName.trim();

    final artistSearches = Map<String, int>.from(state.artistSearches);
    artistSearches[artist] = (artistSearches[artist] ?? 0) + 1;

    final updated = state.copyWith(
      artistSearches: artistSearches,
      lastUpdated: DateTime.now(),
    );
    await _saveToHive(updated);
    
    // Also trigger full recalculation of UserMusicProfile to update search scores
    ref.read(userMusicProfileProvider.notifier).recalculateFull();
    print('🎵 [TasteProfile] Artist search recorded for "$artist"');
  }

  Future<void> trackFavoriteToggle(YoutubeTrack track, bool isFavorited) async {
    final artist = track.artistName;
    final songId = track.id;

    final favorites = Map<String, int>.from(state.favorites);
    if (isFavorited) {
      favorites[songId] = (favorites[songId] ?? 0) + 10; // +10 song affinity
      favorites[artist] = (favorites[artist] ?? 0) + 5;  // +5 artist affinity
      print('🎵 [TasteProfile] Favorite added: +10 song affinity, +5 artist affinity for "$artist"');
    } else {
      favorites[songId] = 0;
      favorites[artist] = (favorites[artist] ?? 0) > 5 ? (favorites[artist] ?? 0) - 5 : 0;
    }

    final updated = state.copyWith(
      favorites: favorites,
      lastUpdated: DateTime.now(),
    );
    await _saveToHive(updated);

    // Also trigger full recalculation of UserMusicProfile to update favorite scores
    ref.read(userMusicProfileProvider.notifier).recalculateFull();
  }

  Future<void> clearTasteProfile() async {
    final box = Hive.box('user_profile');
    await box.delete('taste_profile');
    state = TasteProfile.empty();
    _lastTrackId = null;
    
    ref.read(userMusicProfileProvider.notifier).clearProfile();
    print('🧹 [TasteProfile] Cleared taste profile.');
  }
}

final tasteProfileProvider = StateNotifierProvider<TasteProfileNotifier, TasteProfile>((ref) {
  return TasteProfileNotifier(ref);
});

// ─── User Music Profile Provider ──────────────────────────────────────────────

class UserMusicProfileNotifier extends StateNotifier<UserMusicProfile> {
  final Ref ref;
  UserMusicProfileNotifier(this.ref) : super(UserMusicProfile.empty()) {
    _loadFromHive();
  }

  /// Public accessor — avoids accessing protected `state` from outside the class.
  UserMusicProfile get currentProfile => state;

  void _loadFromHive() {
    final box = Hive.box('user_profile');
    final raw = box.get('music_profile') as String?;
    if (raw != null) {
      try {
        final decoded = json.decode(raw) as Map<String, dynamic>;
        state = UserMusicProfile.fromJson(decoded);
        print('🟢 [UserMusicProfile] Loaded user music profile from Hive.');
      } catch (e) {
        print('🔴 [UserMusicProfile] Failed to decode user music profile: $e');
      }
    }
  }

  Future<void> _saveToHive(UserMusicProfile profile) async {
    final box = Hive.box('user_profile');
    final encoded = json.encode(profile.toJson());
    await box.put('music_profile', encoded);
    state = profile;
  }

  Future<void> clearProfile() async {
    final box = Hive.box('user_profile');
    await box.delete('music_profile');
    state = UserMusicProfile.empty();
    print('🧹 [UserMusicProfile] Cleared user music profile.');
  }

  Future<void> trackPlaybackEvent(YoutubeTrack track, double completionRate) async {
    final artist = track.artistName;
    final songId = track.id;

    int playIncrement = 0;
    int skipIncrement = 0;

    if (completionRate >= 0.90) {
      playIncrement = 2;
    } else if (completionRate >= 0.30) {
      playIncrement = 1;
    } else {
      skipIncrement = 1;
    }

    final box = Hive.box('user_profile');
    final raw = box.get('music_profile') as String?;
    Map<String, int> artistPlays = {};
    Map<String, int> artistSkips = {};
    Map<String, int> songPlays = {};
    Map<String, int> trackPlays = {};
    Map<String, int> trackCompletions = {};
    Map<String, int> artistImpressions = {};
    Map<String, int> artistClicks = {};
    
    if (raw != null) {
      try {
        final decoded = json.decode(raw) as Map<String, dynamic>;
        artistPlays = Map<String, int>.from(decoded['artistPlays'] ?? {});
        artistSkips = Map<String, int>.from(decoded['artistSkips'] ?? {});
        songPlays = Map<String, int>.from(decoded['songPlays'] ?? {});
        trackPlays = Map<String, int>.from(decoded['trackPlays'] ?? decoded['songPlays'] ?? {});
        trackCompletions = Map<String, int>.from(decoded['trackCompletions'] ?? {});
        artistImpressions = Map<String, int>.from(decoded['artistImpressions'] ?? {});
        artistClicks = Map<String, int>.from(decoded['artistClicks'] ?? {});
      } catch (_) {}
    }

    if (playIncrement > 0) {
      artistPlays[artist] = (artistPlays[artist] ?? 0) + playIncrement;
      songPlays[songId] = (songPlays[songId] ?? 0) + playIncrement;
      trackPlays[songId] = (trackPlays[songId] ?? 0) + 1;
      if (completionRate >= 0.90) {
        trackCompletions[songId] = (trackCompletions[songId] ?? 0) + 1;
      }
      if (completionRate == 0.5) {
        artistClicks[artist] = (artistClicks[artist] ?? 0) + 1;
      }
    }
    if (skipIncrement > 0) {
      artistSkips[artist] = (artistSkips[artist] ?? 0) + skipIncrement;
    }

    final preferences = ref.read(userPreferenceProfileProvider);
    final languageScores = Map<String, double>.from(state.languageScores);
    final trackLang = detectTrackLanguage(track, preferences?.languages ?? []);
    if (playIncrement > 0) {
      languageScores[trackLang] = (languageScores[trackLang] ?? 0.0) + (playIncrement * 10.0);
    }
    if (skipIncrement > 0) {
      languageScores[trackLang] = max(0.0, (languageScores[trackLang] ?? 0.0) - (skipIncrement * 15.0));
    }

    final genreScores = Map<String, double>.from(state.genreScores);
    final titleLower = track.title.toLowerCase();
    final genreKeywords = {
      'Melody': ['melody', 'soft', 'acoustic', 'unplugged', 'melody mix', 'soulful'],
      'Romantic': ['love', 'romance', 'romantic', 'dil', 'pyaari', 'priya', 'valentines'],
      'Mass': ['mass', 'beat', 'dance', 'dhol', 'fast', 'kuthu'],
      'Lo-Fi': ['lofi', 'lo-fi', 'study', 'sleep', 'chillout'],
      'EDM': ['edm', 'electronic', 'house', 'club', 'techno', 'dance'],
      'Hip-Hop': ['hip hop', 'rap', 'hiphop', 'r&b', 'trap'],
      'Devotional': ['devotional', 'bhakti', 'shiva', 'krishna', 'prayer', 'temple', 'bhajan'],
      'Workout': ['workout', 'gym', 'energy', 'power', 'fitness'],
      'Chill': ['chill', 'relax', 'soothing', 'ambient', 'calm'],
      'Party': ['party', 'club', 'dance', 'dj', 'celebrate'],
    };
    genreKeywords.forEach((genre, keywords) {
      if (titleLower.contains(genre.toLowerCase()) || keywords.any((kw) => titleLower.contains(kw))) {
        if (playIncrement > 0) {
          genreScores[genre] = (genreScores[genre] ?? 0.0) + (playIncrement * 5.0);
        }
        if (skipIncrement > 0) {
          genreScores[genre] = max(0.0, (genreScores[genre] ?? 0.0) - (skipIncrement * 5.0));
        }
      }
    });

    final themeScores = Map<String, double>.from(state.playlistThemeScores);
    final themeKeywords = {
      'Romance': ['romance', 'romantic', 'love', 'date', 'valentines', 'dil', 'pyaari', 'priya'],
      'Feel Good': ['feel good', 'happy', 'joy', 'upbeat', 'optimistic', 'smile'],
      'Workout': ['workout', 'gym', 'training', 'run', 'cardio', 'fitness', 'power', 'beast'],
      'Energize': ['energize', 'energy', 'power', 'beast', 'party', 'dance', 'workout'],
      'Focus': ['focus', 'study', 'concentration', 'work', 'chill', 'relax', 'instrumental', 'ambient'],
      'Relax': ['relax', 'chill', 'sleep', 'calm', 'acoustic', 'ambient', 'soothing'],
    };
    themeKeywords.forEach((theme, keywords) {
      if (titleLower.contains(theme.toLowerCase()) || keywords.any((kw) => titleLower.contains(kw))) {
        if (playIncrement > 0) {
          themeScores[theme] = (themeScores[theme] ?? 0.0) + (playIncrement * 10.0);
        }
      }
    });

    final library = ref.read(syncedLibraryProvider);
    final artistScores = _recalculateArtistScores(
      artistPlays: artistPlays,
      artistSkips: artistSkips,
      library: library,
      preferences: preferences,
    );

    // Dynamic track score recalculation
    final trackScores = <String, double>{};
    trackPlays.forEach((id, count) {
      final isLiked = library.likedSongs.any((s) => s.id == id);
      bool inPlaylist = false;
      for (final playlistTracks in library.playlistTracks.values) {
        if (playlistTracks.any((t) => t.id == id)) {
          inPlaylist = true;
          break;
        }
      }
      final completions = trackCompletions[id] ?? 0;
      
      double score = count * 2.0 + completions * 5.0;
      if (count > 1) {
        score += (count - 1) * 3.0;
      }
      if (isLiked) {
        score += 10.0;
      }
      if (inPlaylist) {
        score += 5.0;
      }
      if (completions > 0) {
        score += completions * 3.0;
      }
      trackScores[id] = score;
    });

    final updated = UserMusicProfile(
      artistScores: artistScores,
      genreScores: genreScores,
      languageScores: languageScores,
      playlistThemeScores: themeScores,
      trackScores: trackScores,
      trackPlays: trackPlays,
      trackCompletions: trackCompletions,
      artistImpressions: artistImpressions,
      artistClicks: artistClicks,
      totalPlays: state.totalPlays + (playIncrement > 0 ? 1 : 0),
      totalLikes: library.likedSongs.length,
      totalSkips: state.totalSkips + skipIncrement,
      lastUpdated: DateTime.now(),
    );

    final jsonMap = updated.toJson();
    jsonMap['artistPlays'] = artistPlays;
    jsonMap['artistSkips'] = artistSkips;
    jsonMap['songPlays'] = songPlays;

    await _saveToHive(updated);
    // Overwrite the save with helper fields
    await box.put('music_profile', json.encode(jsonMap));
  }

  Map<String, double> _recalculateArtistScores({
    required Map<String, int> artistPlays,
    required Map<String, int> artistSkips,
    required SyncedLibraryState library,
    required UserPreferenceProfile? preferences,
  }) {
    final allArtists = <String>{};
    if (preferences != null) {
      allArtists.addAll(preferences.artists);
    }
    final subscribedArtists = library.musicArtists.map((c) => c.name).toList();
    allArtists.addAll(subscribedArtists);
    
    final likedArtists = library.likedSongs.map((s) => s.artistName).toList();
    allArtists.addAll(likedArtists);
    
    final playlistArtists = <String>[];
    for (final tracks in library.playlistTracks.values) {
      for (final t in tracks) {
        playlistArtists.add(t.artistName);
      }
    }
    allArtists.addAll(playlistArtists);
    allArtists.addAll(artistPlays.keys);
    allArtists.addAll(artistSkips.keys);

    final playlistAppearances = <String, int>{};
    for (final artist in playlistArtists) {
      playlistAppearances[artist] = (playlistAppearances[artist] ?? 0) + 1;
    }

    final likedCounts = <String, int>{};
    for (final artist in likedArtists) {
      likedCounts[artist] = (likedCounts[artist] ?? 0) + 1;
    }

    final artistScores = <String, double>{};
    for (final artist in allArtists) {
      if (artist.trim().isEmpty || artist.length > 35) continue;

      final isSubscribed = subscribedArtists.any((name) => name.toLowerCase().trim() == artist.toLowerCase().trim());
      final subScore = isSubscribed ? 1.0 : 0.0;

      final isOnboarding = preferences?.artists.any((name) => name.toLowerCase().trim() == artist.toLowerCase().trim()) ?? false;
      final onboardingScore = isOnboarding ? 1.0 : 0.0;

      final likesCount = likedCounts[artist] ?? 0;
      final playCount = artistPlays[artist] ?? 0;
      final playlistCount = playlistAppearances[artist] ?? 0;
      final skipCount = artistSkips[artist] ?? 0;

      final score = (subScore * 10.0) +
                    (likesCount * 6.0) +
                    (playCount * 2.0) +
                    (playlistCount * 1.0) +
                    (onboardingScore * 4.0) -
                    (skipCount * 5.0);

      artistScores[artist] = score;
    }
    return artistScores;
  }

  Future<void> recalculateFull() async {
    final preferences = ref.read(userPreferenceProfileProvider);
    final library = ref.read(syncedLibraryProvider);

    final box = Hive.box('user_profile');
    final raw = box.get('music_profile') as String?;
    Map<String, int> artistPlays = {};
    Map<String, int> artistSkips = {};
    Map<String, int> songPlays = {};
    Map<String, int> trackPlays = {};
    Map<String, int> trackCompletions = {};
    Map<String, int> artistImpressions = {};
    Map<String, int> artistClicks = {};

    if (raw != null) {
      try {
        final decoded = json.decode(raw) as Map<String, dynamic>;
        artistPlays = Map<String, int>.from(decoded['artistPlays'] ?? {});
        artistSkips = Map<String, int>.from(decoded['artistSkips'] ?? {});
        songPlays = Map<String, int>.from(decoded['songPlays'] ?? {});
        trackPlays = Map<String, int>.from(decoded['trackPlays'] ?? decoded['songPlays'] ?? {});
        trackCompletions = Map<String, int>.from(decoded['trackCompletions'] ?? {});
        artistImpressions = Map<String, int>.from(decoded['artistImpressions'] ?? {});
        artistClicks = Map<String, int>.from(decoded['artistClicks'] ?? {});
      } catch (_) {}
    }

    final artistScores = _recalculateArtistScores(
      artistPlays: artistPlays,
      artistSkips: artistSkips,
      library: library,
      preferences: preferences,
    );

    final languageScores = Map<String, double>.from(state.languageScores);
    if (preferences != null) {
      for (final lang in preferences.languages) {
        if (!languageScores.containsKey(lang)) {
          languageScores[lang] = 100.0;
        }
      }
    }

    final genreScores = Map<String, double>.from(state.genreScores);
    if (preferences != null) {
      for (final genre in preferences.genres) {
        if (!genreScores.containsKey(genre)) {
          genreScores[genre] = 100.0;
        }
      }
    }

    for (final p in library.playlists) {
      final title = p.title.toLowerCase();
      final genreKeywords = {
        'Melody': ['melody', 'soft', 'acoustic', 'unplugged', 'melody mix', 'soulful'],
        'Romantic': ['love', 'romance', 'romantic', 'dil', 'pyaari', 'priya', 'valentines'],
        'Mass': ['mass', 'beat', 'dance', 'dhol', 'fast', 'kuthu'],
        'Lo-Fi': ['lofi', 'lo-fi', 'study', 'sleep', 'chillout'],
        'EDM': ['edm', 'electronic', 'house', 'club', 'techno', 'dance'],
        'Hip-Hop': ['hip hop', 'rap', 'hiphop', 'r&b', 'trap'],
        'Devotional': ['devotional', 'bhakti', 'shiva', 'krishna', 'prayer', 'temple', 'bhajan'],
        'Workout': ['workout', 'gym', 'energy', 'power', 'fitness'],
        'Chill': ['chill', 'relax', 'soothing', 'ambient', 'calm'],
        'Party': ['party', 'club', 'dance', 'dj', 'celebrate'],
      };
      genreKeywords.forEach((genre, keywords) {
        if (title.contains(genre.toLowerCase()) || keywords.any((kw) => title.contains(kw))) {
          genreScores[genre] = (genreScores[genre] ?? 0.0) + 20.0;
        }
      });
    }

    final themeScores = Map<String, double>.from(state.playlistThemeScores);
    for (final p in library.playlists) {
      final title = p.title.toLowerCase();
      final themeKeywords = {
        'Romance': ['romance', 'romantic', 'love', 'date', 'valentines', 'dil', 'pyaari', 'priya'],
        'Feel Good': ['feel good', 'happy', 'joy', 'upbeat', 'optimistic', 'smile'],
        'Workout': ['workout', 'gym', 'training', 'run', 'cardio', 'fitness', 'power', 'beast'],
        'Energize': ['energize', 'energy', 'power', 'beast', 'party', 'dance', 'workout'],
        'Focus': ['focus', 'study', 'concentration', 'work', 'chill', 'relax', 'instrumental', 'ambient'],
        'Relax': ['relax', 'chill', 'sleep', 'calm', 'acoustic', 'ambient', 'soothing'],
      };
      themeKeywords.forEach((theme, keywords) {
        if (title.contains(theme.toLowerCase()) || keywords.any((kw) => title.contains(kw))) {
          themeScores[theme] = (themeScores[theme] ?? 0.0) + 20.0;
        }
      });
    }

    // Dynamic track score recalculation
    final trackScores = <String, double>{};
    trackPlays.forEach((id, count) {
      final isLiked = library.likedSongs.any((s) => s.id == id);
      bool inPlaylist = false;
      for (final playlistTracks in library.playlistTracks.values) {
        if (playlistTracks.any((t) => t.id == id)) {
          inPlaylist = true;
          break;
        }
      }
      final completions = trackCompletions[id] ?? 0;
      
      double score = count * 2.0 + completions * 5.0;
      if (count > 1) {
        score += (count - 1) * 3.0;
      }
      if (isLiked) {
        score += 10.0;
      }
      if (inPlaylist) {
        score += 5.0;
      }
      if (completions > 0) {
        score += completions * 3.0;
      }
      trackScores[id] = score;
    });

    int totalPlays = 0;
    songPlays.values.forEach((v) => totalPlays += v);

    int totalSkips = 0;
    artistSkips.values.forEach((v) => totalSkips += v);

    final updated = UserMusicProfile(
      artistScores: artistScores,
      genreScores: genreScores,
      languageScores: languageScores,
      playlistThemeScores: themeScores,
      trackScores: trackScores,
      trackPlays: trackPlays,
      trackCompletions: trackCompletions,
      artistImpressions: artistImpressions,
      artistClicks: artistClicks,
      totalPlays: totalPlays,
      totalLikes: library.likedSongs.length,
      totalSkips: totalSkips,
      lastUpdated: DateTime.now(),
    );

    final jsonMap = updated.toJson();
    jsonMap['artistPlays'] = artistPlays;
    jsonMap['artistSkips'] = artistSkips;
    jsonMap['songPlays'] = songPlays;

    await box.put('music_profile', json.encode(jsonMap));
    state = updated;
    print('💾 [UserMusicProfile] Performed full recalculation and saved to Hive.');
  }

  Future<void> recordArtistImpressions(List<String> artists) async {
    final box = Hive.box('user_profile');
    final raw = box.get('music_profile') as String?;
    Map<String, int> artistPlays = {};
    Map<String, int> artistSkips = {};
    Map<String, int> songPlays = {};
    Map<String, int> artistImpressions = {};
    
    if (raw != null) {
      try {
        final decoded = json.decode(raw) as Map<String, dynamic>;
        artistPlays = Map<String, int>.from(decoded['artistPlays'] ?? {});
        artistSkips = Map<String, int>.from(decoded['artistSkips'] ?? {});
        songPlays = Map<String, int>.from(decoded['songPlays'] ?? {});
        artistImpressions = Map<String, int>.from(decoded['artistImpressions'] ?? {});
      } catch (_) {}
    }

    for (final artist in artists) {
      artistImpressions[artist] = (artistImpressions[artist] ?? 0) + 1;
    }

    final updated = state.copyWith(
      artistImpressions: artistImpressions,
      lastUpdated: DateTime.now(),
    );

    final jsonMap = updated.toJson();
    jsonMap['artistPlays'] = artistPlays;
    jsonMap['artistSkips'] = artistSkips;
    jsonMap['songPlays'] = songPlays;

    await _saveToHive(updated);
    await box.put('music_profile', json.encode(jsonMap));
  }
}

final userMusicProfileProvider = StateNotifierProvider<UserMusicProfileNotifier, UserMusicProfile>((ref) {
  final notifier = UserMusicProfileNotifier(ref);

  if (notifier.currentProfile.artistScores.isEmpty) {
    Future.microtask(() => notifier.recalculateFull());
  }

  ref.listen<SyncedLibraryState>(syncedLibraryProvider, (previous, next) {
    if (previous?.isLoading == true && next.isLoading == false) {
      notifier.recalculateFull();
    }
  });

  ref.listen<UserPreferenceProfile?>(userPreferenceProfileProvider, (previous, next) {
    notifier.recalculateFull();
  });

  return notifier;
});

// ─── Recommendation Utilities ─────────────────────────────────────────────────

/// Calculate total playCount in profile. Used for weight transition.
int getTasteProfileTotalPlays(TasteProfile profile) {
  int total = 0;
  for (final count in profile.songPlays.values) {
    total += count;
  }
  return total;
}

/// Calculate weight for onboarding vs behavior based on total plays (Phase 6)
Map<String, double> getPersonalizationWeights(int totalPlays) {
  if (totalPlays < 100) {
    return {'onboarding': 0.70, 'behavior': 0.30};
  } else if (totalPlays < 500) {
    return {'onboarding': 0.30, 'behavior': 0.70};
  } else {
    return {'onboarding': 0.10, 'behavior': 0.90};
  }
}

/// Calculates ArtistScore (Phase 4) incorporating learning weights (Phase 6)
double calculateArtistScore({
  required String artistName,
  required UserPreferenceProfile? preferences,
  required TasteProfile taste,
  required int totalPlays,
}) {
  final weights = getPersonalizationWeights(totalPlays);
  final wOnboarding = weights['onboarding']!;
  final wBehavior = weights['behavior']!;

  // Onboarding score
  final isOnboardingArtist = preferences?.artists.any(
        (a) => a.toLowerCase().trim() == artistName.toLowerCase().trim(),
      ) ??
      false;
  final onboardingScore = isOnboardingArtist ? 5.0 : 0.0;

  // Behavior score
  final playCount = taste.artistPlays[artistName] ?? 0;
  final favoriteCount = taste.favorites[artistName] ?? 0;
  final searchCount = taste.artistSearches[artistName] ?? 0;
  final skipCount = taste.skips[artistName] ?? 0;

  final behaviorScore = (playCount * 3.0) + (favoriteCount * 5.0) + (searchCount * 2.0) - (skipCount * 2.0);

  return (wOnboarding * onboardingScore) + (wBehavior * behaviorScore);
}

/// Sort all known artists descending by their calculated ArtistScore
List<MapEntry<String, double>> getScoredArtists({
  required UserPreferenceProfile? preferences,
  required TasteProfile taste,
  UserMusicProfile? musicProfile,
}) {
  if (musicProfile != null) {
    return musicProfile.artistScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
  }

  final allArtists = <String>{};
  if (preferences != null) {
    allArtists.addAll(preferences.artists);
  }
  allArtists.addAll(taste.artistPlays.keys);
  allArtists.addAll(taste.artistSearches.keys);
  allArtists.addAll(taste.favorites.keys.where((k) => !k.startsWith('playlist_') && k.length > 3));

  final totalPlays = getTasteProfileTotalPlays(taste);
  final scores = <String, double>{};

  for (final artist in allArtists) {
    if (artist.contains('_') || artist.length > 35) continue;
    scores[artist] = calculateArtistScore(
      artistName: artist,
      preferences: preferences,
      taste: taste,
      totalPlays: totalPlays,
    );
  }

  return scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
}

// ─── Language Detection & Song Scoring (Phases 7 & 11) ────────────────────────

String detectTrackLanguage(YoutubeTrack track, List<String> preferredLanguages) {
  final title = track.title.toLowerCase();
  final artist = track.artistName.toLowerCase();

  if (artist.contains('anirudh')) {
    return preferredLanguages.contains('Telugu') ? 'Telugu' : 'Tamil';
  }
  if (artist.contains('arijit') || artist.contains('jubin') || artist.contains('neha kakkar')) {
    return 'Hindi';
  }
  if (artist.contains('sid sriram')) {
    if (preferredLanguages.contains('Telugu')) return 'Telugu';
    if (preferredLanguages.contains('Tamil')) return 'Tamil';
    if (preferredLanguages.contains('Malayalam')) return 'Malayalam';
    if (preferredLanguages.contains('Kannada')) return 'Kannada';
    return 'Telugu';
  }
  if (artist.contains('rahman')) {
    if (preferredLanguages.contains('Tamil')) return 'Tamil';
    if (preferredLanguages.contains('Hindi')) return 'Hindi';
    if (preferredLanguages.contains('Telugu')) return 'Telugu';
    return 'Tamil';
  }
  if (artist.contains('weeknd') || artist.contains('sheeran') || artist.contains('swift') || artist.contains('bts') || artist.contains('billie') || artist.contains('dua lipa')) {
    return 'English';
  }
  if (artist.contains('diljit') || artist.contains('sidhu') || artist.contains('ap dhillon') || artist.contains('shubh')) {
    return 'Punjabi';
  }

  if (title.contains('telugu') || title.contains('pata') || title.contains('geetha') || title.contains('samajavaragamana') || title.contains('alavaikunthapurramuloo') || title.contains('buttabomma') || title.contains('srivalli') || title.contains('bheemla') || title.contains('saranga')) {
    return 'Telugu';
  }
  if (title.contains('hindi') || title.contains('dil') || title.contains('tum') || title.contains('pyar') || title.contains('meri') || title.contains('teri') || title.contains('kesariya') || title.contains('ishq')) {
    return 'Hindi';
  }
  if (title.contains('tamil') || title.contains('kadhale') || title.contains('kannana') || title.contains('vaathi') || title.contains('arabic kuthu') || title.contains('rowdy baby') || title.contains('ponniyin')) {
    return 'Tamil';
  }
  if (title.contains('malayalam') || title.contains('hridyam') || title.contains('darshana') || title.contains('kumbalangi') || title.contains('jimmiki')) {
    return 'Malayalam';
  }
  if (title.contains('kannada') || title.contains('kgf') || title.contains('raajakumara') || title.contains('sandalwood')) {
    return 'Kannada';
  }
  if (title.contains('punjabi') || title.contains('jatt') || title.contains('brown munde') || title.contains('lalkara') || title.contains('moosewala')) {
    return 'Punjabi';
  }

  for (final lang in preferredLanguages) {
    if (title.contains(lang.toLowerCase())) return lang;
  }

  if (preferredLanguages.isNotEmpty) {
    return preferredLanguages.first;
  }
  return 'English';
}

Map<String, double> getLanguageDistribution({
  required UserPreferenceProfile? preferences,
  required List<YoutubeTrack> recentPlayed,
}) {
  final distribution = <String, double>{};
  if (preferences == null || preferences.languages.isEmpty) {
    return {'English': 1.0};
  }

  final counts = <String, double>{};
  for (final lang in preferences.languages) {
    counts[lang] = 5.0;
  }

  for (final track in recentPlayed) {
    final lang = detectTrackLanguage(track, preferences.languages);
    counts[lang] = (counts[lang] ?? 0.0) + 1.0;
  }

  double total = 0.0;
  for (final count in counts.values) {
    total += count;
  }

  if (total > 0) {
    for (final entry in counts.entries) {
      distribution[entry.key] = entry.value / total;
    }
  } else {
    for (final lang in preferences.languages) {
      distribution[lang] = 1.0 / preferences.languages.length;
    }
  }

  return distribution;
}

double calculateSongScore({
  required YoutubeTrack track,
  required UserPreferenceProfile? preferences,
  required SyncedLibraryState library,
  required UserMusicProfile musicProfile,
  required SessionProfile? sessionProfile,
  required List<String> similarArtists,
  required double skipPenalty,
  required bool isSuppressed,
  required double artistFatigue,
  bool isDiscovery = false,
}) {
  final songId = track.id;
  final artist = track.artistName;

  // 1. Track Affinity (40% weight)
  // Compute TrackAffinity from profile
  final plays = musicProfile.trackPlays[songId] ?? 0;
  final completions = musicProfile.trackCompletions[songId] ?? 0;
  final isLiked = library.likedSongs.any((s) => s.id == songId);
  bool inPlaylist = false;
  for (final playlistTracks in library.playlistTracks.values) {
    if (playlistTracks.any((t) => t.id == songId)) {
      inPlaylist = true;
      break;
    }
  }
  double trackAffinity = plays * 2.0 + completions * 5.0;
  if (plays > 1) {
    trackAffinity += (plays - 1) * 3.0;
  }
  if (isLiked) {
    trackAffinity += 10.0;
  }
  if (inPlaylist) {
    trackAffinity += 5.0;
  }
  if (completions > 0) {
    trackAffinity += completions * 3.0;
  }
  trackAffinity = trackAffinity.clamp(0.0, 100.0);

  // 2. Session Context (30% weight)
  double sessionContext = 0.0;
  if (sessionProfile != null) {
    final trackLang = track.language ?? detectTrackLanguage(track, preferences?.languages ?? []);
    if (sessionProfile.dominantLanguage.toLowerCase() == trackLang.toLowerCase()) {
      sessionContext += 40.0;
    }
    if (sessionProfile.dominantArtists.any((name) => name.toLowerCase().trim() == artist.toLowerCase().trim())) {
      sessionContext += 40.0;
    }
    
    // Genre matching
    final titleLower = track.title.toLowerCase();
    String genre = 'Unknown';
    if (titleLower.contains('melody') || titleLower.contains('soft') || titleLower.contains('acoustic')) {
      genre = 'Melody';
    } else if (titleLower.contains('love') || titleLower.contains('romantic') || titleLower.contains('dil')) {
      genre = 'Romantic';
    } else if (titleLower.contains('edm') || titleLower.contains('dance') || titleLower.contains('electronic')) {
      genre = 'EDM';
    }
    if (genre != 'Unknown' && sessionProfile.dominantGenre.toLowerCase() == genre.toLowerCase()) {
      sessionContext += 20.0;
    }

    // Mood matching (backed by reliable metadata)
    if (sessionProfile.dominantMood != 'Unknown' && track.mood != null && sessionProfile.dominantMood.toLowerCase() == track.mood!.toLowerCase()) {
      sessionContext += 10.0;
    }
    // Energy score matching (backed by reliable metadata)
    if (track.energyScore != null && (track.energyScore! - sessionProfile.energyScore).abs() < 0.2) {
      sessionContext += 10.0;
    }
  }
  sessionContext = sessionContext.clamp(0.0, 100.0);

  // 3. Artist Affinity (15% weight)
  double artistAffinity = musicProfile.artistScores[artist] ?? 0.0;
  
  // Apply fatigue penalty to Artist Affinity
  if (artistFatigue > 0.95) {
    artistAffinity *= 0.00; // Suppressed
  } else if (artistFatigue > 0.85) {
    artistAffinity *= 0.50; // -50%
  } else if (artistFatigue > 0.70) {
    artistAffinity *= 0.75; // -25%
  }
  artistAffinity = artistAffinity.clamp(-50.0, 100.0);

  // 5. Discovery (10% weight)
  double discoveryBoost = isDiscovery ? 100.0 : 0.0;

  // 6. Freshness (5% weight)
  double freshnessScore = 0.0;
  if (track.releaseYear != null) {
    if (track.releaseYear == 2026) {
      freshnessScore = 100.0;
    } else if (track.releaseYear == 2025) {
      freshnessScore = 50.0;
    }
  } else {
    // Fallback heuristic based on title/releaseDate
    final titleLower = track.title.toLowerCase();
    if (titleLower.contains('new release') || titleLower.contains('latest') || titleLower.contains('2026')) {
      freshnessScore = 100.0;
    } else if (titleLower.contains('2025')) {
      freshnessScore = 50.0;
    }
  }

  // Final Weighted score (v4.1 formula)
  double score = (trackAffinity * 0.40) +
                 (sessionContext * 0.30) +
                 (artistAffinity * 0.15) +
                 (discoveryBoost * 0.10) +
                 (freshnessScore * 0.05);

  // Apply skip penalties and suppression penalties
  score += skipPenalty; // skipPenalty is negative (e.g. -5, -15, -30)
  if (isSuppressed) {
    score -= 500.0; // Pushed to the bottom
  }

  return score;
}

final songScorerProvider = Provider<double Function(YoutubeTrack, {bool isDiscovery})>((ref) {
  final preferences = ref.watch(userPreferenceProfileProvider);
  final library = ref.watch(syncedLibraryProvider);
  final musicProfile = ref.watch(userMusicProfileProvider);
  final sessionProfile = ref.watch(sessionIntelligenceProvider).getCurrentSessionProfile();
  final similarityService = ref.watch(artistSimilarityProvider);
  final negativeLearning = ref.watch(negativeLearningProvider);

  return (YoutubeTrack track, {bool isDiscovery = false}) {
    final artist = track.artistName;
    final similarArtists = similarityService.getSimilarArtists(artist);
    final skipPenalty = negativeLearning.getSkipPenalty(artist);
    final isSuppressed = negativeLearning.isSuppressed(artist);
    
    final impressions = musicProfile.artistImpressions[artist] ?? 0;
    final clicks = musicProfile.artistClicks[artist] ?? 0;
    final artistFatigue = impressions > 0 ? (impressions - clicks) / impressions : 0.0;

    return calculateSongScore(
      track: track,
      preferences: preferences,
      library: library,
      musicProfile: musicProfile,
      sessionProfile: sessionProfile,
      similarArtists: similarArtists,
      skipPenalty: skipPenalty,
      isSuppressed: isSuppressed,
      artistFatigue: artistFatigue,
      isDiscovery: isDiscovery,
    );
  };
});
