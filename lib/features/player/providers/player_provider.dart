import 'dart:ui';
import 'dart:convert';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/services/audio_player_handler.dart';
import '../../youtube/data/models/youtube_track.dart';
import '../../youtube/providers/youtube_providers.dart';
import '../../../core/utils/image_color_extractor.dart';
import '../../auth/providers/personalization_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/services/autoplay_queue_generator.dart';
import '../../youtube/data/services/session_intelligence_service.dart';
import '../../youtube/data/services/taste_cluster_service.dart';

/// Global instance of the audio handler.
/// Initialized in main.dart before runApp().
late AudioPlayerHandler audioHandler;

/// Tracks whether a song is currently being loaded (resolving stream URL).
final isLoadingTrackProvider = StateProvider<bool>((ref) => false);

/// Tracks the ID of the track currently being loaded.
final loadingTrackIdProvider = StateProvider<String?>((ref) => null);

/// Tracks error messages from the player to show to the user.
final playerErrorProvider = StateProvider<String?>((ref) => null);

/// Tracks whether queue recovery mode is active.
final queueRecoveryModeProvider = StateProvider<bool>((ref) => false);

// Keep track of skips locally in the provider layer
int _consecutiveSkipsCount = 0;
Timer? _playTimer;

/// Exposes the AudioPlayerHandler for UI controls (play, pause, etc).
final playerHandlerProvider = Provider<AudioPlayerHandler>((ref) {
  // Wire up the status callback here where we have access to the ref
  audioHandler.onStatusChanged = ({
    required bool isLoading,
    String? loadingTrackId,
    String? error,
  }) {
    // Need to use Future.microtask to avoid modifying providers during build phase
    Future.microtask(() {
      ref.read(isLoadingTrackProvider.notifier).state = isLoading;
      ref.read(loadingTrackIdProvider.notifier).state = loadingTrackId;
      if (error != null) {
        ref.read(playerErrorProvider.notifier).state = error;
      }
    });
  };

  // Wire up personalization event handlers
  audioHandler.onTrackStart = (track) {
    ref.read(tasteProfileProvider.notifier).trackSongStart(track);
    ref.read(sessionIntelligenceProvider).recordPlay(track);

    // If the song plays for 20s, reset consecutive skips and exit recovery mode
    _playTimer?.cancel();
    _playTimer = Timer(const Duration(seconds: 20), () {
      if (_consecutiveSkipsCount > 0) {
        print('⏱️ [SkipRecovery] Track played for 20s. Resetting consecutive skips.');
        _consecutiveSkipsCount = 0;
        ref.read(queueRecoveryModeProvider.notifier).state = false;
      }
    });
  };

  audioHandler.onTrackComplete = (track) {
    ref.read(tasteProfileProvider.notifier).trackSongComplete(track);
    _consecutiveSkipsCount = 0;
    ref.read(queueRecoveryModeProvider.notifier).state = false;
    _playTimer?.cancel();
  };

  audioHandler.onTrackSkip = (track, elapsed, total) async {
    ref.read(tasteProfileProvider.notifier).trackSongSkip(track, elapsed, total);
    _playTimer?.cancel();

    if (elapsed.inSeconds < 20) {
      _consecutiveSkipsCount++;
      print('⚠️ [SkipRecovery] Track skipped in under 20s. Consecutive skips: $_consecutiveSkipsCount');
      if (_consecutiveSkipsCount >= 3) {
        print('🚨 [SkipRecovery] 3 consecutive skips detected! Activating queue recovery mode...');
        ref.read(queueRecoveryModeProvider.notifier).state = true;

        // Rebuild autoplay queue immediately
        try {
          final repo = await ref.read(ytMusicRepositoryProvider.future);
          final preferences = ref.read(userPreferenceProfileProvider);
          final recentPlayed = ref.read(recentlyPlayedProvider);
          final library = ref.read(syncedLibraryProvider);
          final scoreTrack = ref.read(songScorerProvider);
          final sessionProfile = ref.read(sessionIntelligenceProvider).getCurrentSessionProfile();
          final tasteClusters = ref.read(tasteClusterProvider).generateTasteClusters(
            preferences: preferences,
            library: library,
            musicProfile: ref.read(userMusicProfileProvider),
          );

          final newQueue = await AutoplayQueueGenerator.generateQueue(
            currentTrack: track,
            repo: repo,
            preferences: preferences,
            recentPlayed: recentPlayed,
            library: library,
            musicProfile: ref.read(userMusicProfileProvider),
            sessionProfile: sessionProfile,
            tasteClusters: tasteClusters,
            scoreTrack: scoreTrack,
            recoveryMode: true,
          );

          if (newQueue.isNotEmpty) {
            final curIdx = audioHandler.currentIndex;
            if (audioHandler.queueList.length > curIdx + 1) {
              audioHandler.queueList.removeRange(curIdx + 1, audioHandler.queueList.length);
            }
            for (final rec in newQueue) {
              if (!audioHandler.queueList.any((t) => t.id == rec.id)) {
                audioHandler.queueList.add(rec);
              }
            }
            print('🟢 [SkipRecovery] Rebuilt autoplay queue in recovery mode.');
          }
        } catch (e) {
          print('🔴 [SkipRecovery] Failed to rebuild queue: $e');
        }
      }
    } else {
      _consecutiveSkipsCount = 0;
      ref.read(queueRecoveryModeProvider.notifier).state = false;
    }
  };

  // Wire up the dynamic recommended songs populator (YouTube Music Radio queue)
  audioHandler.onFetchRecommendations = (videoId) async {
    try {
      final repo = await ref.read(ytMusicRepositoryProvider.future);
      final currentTrack = audioHandler.currentYoutubeTrack;
      if (currentTrack == null) return [];
      
      final preferences = ref.read(userPreferenceProfileProvider);
      final recentPlayed = ref.read(recentlyPlayedProvider);
      final library = ref.read(syncedLibraryProvider);
      final scoreTrack = ref.read(songScorerProvider);
      final sessionProfile = ref.read(sessionIntelligenceProvider).getCurrentSessionProfile();
      final tasteClusters = ref.read(tasteClusterProvider).generateTasteClusters(
        preferences: preferences,
        library: library,
        musicProfile: ref.read(userMusicProfileProvider),
      );
      final recoveryMode = ref.read(queueRecoveryModeProvider);

      return await AutoplayQueueGenerator.generateQueue(
        currentTrack: currentTrack,
        repo: repo,
        preferences: preferences,
        recentPlayed: recentPlayed,
        library: library,
        musicProfile: ref.read(userMusicProfileProvider),
        sessionProfile: sessionProfile,
        tasteClusters: tasteClusters,
        scoreTrack: scoreTrack,
        recoveryMode: recoveryMode,
      );
    } catch (e) {
      print('🔴 [playerHandlerProvider] Error auto-generating recommended queue: $e');
      return [];
    }
  };

  audioHandler.onSessionRestored = (track, savedPosition) {
    Future.microtask(() {
      ref.read(restoredSessionTrackProvider.notifier).state = track;
      ref.read(restoredSessionPositionProvider.notifier).state = savedPosition;
    });
  };

  // Safety net: if restoreLastSession fired before the callback was wired,
  // read the handler fields directly and populate providers now.
  final alreadyRestoredTrack = audioHandler.lastRestoredTrack;
  if (alreadyRestoredTrack != null) {
    Future.microtask(() {
      ref.read(restoredSessionTrackProvider.notifier).state = alreadyRestoredTrack;
      ref.read(restoredSessionPositionProvider.notifier).state = audioHandler.lastRestoredPosition;
    });
  }

  return audioHandler;
});

/// Provides the last restored session track (available immediately on app launch,
/// before audio is loaded). Cleared when a new song starts playing.
final restoredSessionTrackProvider = StateProvider<YoutubeTrack?>((ref) => null);

/// Provides the saved seek position for the restored session track.
final restoredSessionPositionProvider = StateProvider<Duration>((ref) => Duration.zero);

/// Exposes the currently playing track.
final currentTrackProvider = StreamProvider<YoutubeTrack?>((ref) {
  final handler = ref.watch(playerHandlerProvider);
  return handler.mediaItem.map((item) {
    if (item == null) return null;
    // Clear the restored session once a real track starts playing
    Future.microtask(() {
      ref.read(restoredSessionTrackProvider.notifier).state = null;
    });
    return handler.currentYoutubeTrack;
  });
});

/// Exposes the current playback state (Playing, Paused, etc).
final playbackStateProvider = StreamProvider<PlaybackState>((ref) {
  return ref.watch(playerHandlerProvider).playbackState;
});

/// Exposes the real-time position stream of the player.
final playerPositionProvider = StreamProvider<Duration>((ref) {
  return ref.watch(playerHandlerProvider).positionStream;
});

/// Exposes the real-time duration stream of the player.
final playerDurationProvider = StreamProvider<Duration?>((ref) {
  return ref.watch(playerHandlerProvider).durationStream;
});

/// Exposes the real-time buffered position stream of the player.
final playerBufferedPositionProvider = StreamProvider<Duration>((ref) {
  return ref.watch(playerHandlerProvider).bufferedPositionStream;
});

/// Exposes a dynamic color palette extracted from the current track's artwork.
final currentTrackPaletteProvider = FutureProvider<Map<String, Color?>>((ref) async {
  final track = ref.watch(currentTrackProvider).value;
  if (track == null || track.artworkUrl == null) {
    return const {};
  }
  return ImageColorExtractor.extractPalette(track.artworkUrl!);
});

// ─── Playback History (Recently Played) ──────────────────────────────────────

class RecentlyPlayedNotifier extends StateNotifier<List<YoutubeTrack>> {
  RecentlyPlayedNotifier() : super(const []) {
    _loadHistory();
  }

  static const String _keyHistory = 'yt_player_recently_played';

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_keyHistory);
      if (historyJson != null) {
        final List<dynamic> decoded = json.decode(historyJson);
        final tracks = decoded.map((e) => _trackFromJson(e as Map<String, dynamic>)).toList();
        state = tracks;
      }
    } catch (e) {
      print('🔴 [RecentlyPlayedNotifier] Error loading history: $e');
    }
  }

  Future<void> addTrack(YoutubeTrack track) async {
    // Exclude special ID types or placeholders if any, but regular tracks should be logged.
    // Create a new list without the current track to avoid duplicates
    final updatedList = List<YoutubeTrack>.from(state)..removeWhere((t) => t.id == track.id);
    
    // Add to the front
    updatedList.insert(0, track);
    
    // Keep only the most recent 50 tracks
    if (updatedList.length > 50) {
      updatedList.removeRange(50, updatedList.length);
    }
    
    state = updatedList;

    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = json.encode(updatedList.map((t) => _trackToJson(t)).toList());
      await prefs.setString(_keyHistory, encoded);
    } catch (e) {
      print('🔴 [RecentlyPlayedNotifier] Error saving history: $e');
    }
  }

  Future<void> clearHistory() async {
    state = const [];
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyHistory);
    } catch (e) {
      print('🔴 [RecentlyPlayedNotifier] Error clearing history: $e');
    }
  }

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
    );
  }
}

final recentlyPlayedProvider = StateNotifierProvider<RecentlyPlayedNotifier, List<YoutubeTrack>>((ref) {
  return RecentlyPlayedNotifier();
});

