import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';
import 'web_audio_player_helper.dart';

import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../../../youtube/data/models/youtube_track.dart';
import 'youtube_stream_resolver.dart';
import 'proxy_audio_source.dart';
import '../../../youtube/data/services/song_runtime_validator.dart';

/// Callback type for notifying the UI about loading/error state changes.
typedef PlayerStatusCallback = void Function({
  required bool isLoading,
  String? loadingTrackId,
  String? error,
});

/// Background audio handler implementation.
class AudioPlayerHandler extends BaseAudioHandler with SeekHandler {
  final _player = AudioPlayer();
  final _streamResolver = YoutubeStreamResolver();
  final _webPlayer = WebAudioPlayerHelper();
  YoutubeTrack? currentYoutubeTrack;

  // ─── Autoplay Queue & Settings ───
  List<YoutubeTrack> queueList = [];
  int currentIndex = -1;
  bool isShuffleEnabled = false;
  bool isLoopOneEnabled = false;

  // ─── Resilient Stall Detection & Pre-resolution Fields ───
  Duration? _lastPosition;
  int _stallCount = 0;
  Timer? _stallTimer;
  Timer? _sessionTimer;
  int _retryCount = 0;

  /// Optional callback to notify the UI about loading/error states.
  /// Set this from the provider layer after initialization.
  PlayerStatusCallback? onStatusChanged;

  /// Callback to fetch recommended tracks from YT Music repository.
  Future<List<YoutubeTrack>> Function(String videoId)? onFetchRecommendations;

  // Personalization TasteProfile Event Hooks
  void Function(YoutubeTrack track)? onTrackStart;
  void Function(YoutubeTrack track)? onTrackComplete;
  void Function(YoutubeTrack track, Duration elapsed, Duration total)? onTrackSkip;

  /// Called when a previous session has been restored, before audio loading begins.
  /// Used by the mini player to show the last played track immediately on launch.
  void Function(YoutubeTrack track, Duration savedPosition)? onSessionRestored;

  // Web specific state properties to match standard just_audio values
  bool _webPlaying = false;
  bool _usingWebIframe = false;
  AudioProcessingState _webProcessingState = AudioProcessingState.idle;
  Duration _webPosition = Duration.zero;
  Duration _webDuration = Duration.zero;

  final _webPositionController = StreamController<Duration>.broadcast();
  final _webDurationController = StreamController<Duration?>.broadcast();
  final _webBufferedPositionController = StreamController<Duration>.broadcast();

  bool _playingOffline = false;

  /// Last track/position from a restored session — set before onSessionRestored fires
  /// so the provider can read it even if the callback wasn't wired yet.
  YoutubeTrack? lastRestoredTrack;
  Duration lastRestoredPosition = Duration.zero;

  Stream<Duration> get positionStream => (kIsWeb && _usingWebIframe && !_playingOffline) ? _webPositionController.stream : _player.positionStream;
  Stream<Duration?> get durationStream => (kIsWeb && _usingWebIframe && !_playingOffline) ? _webDurationController.stream : _player.durationStream;
  Stream<Duration> get bufferedPositionStream => (kIsWeb && _usingWebIframe && !_playingOffline) ? _webBufferedPositionController.stream : _player.bufferedPositionStream;

  AudioPlayerHandler() {
    if (kIsWeb) {
      _player.setWebCrossOrigin(null);

      _webPlayer.initWebListeners(
        onStateChange: (stateStr, positionSec, durationSec) {
          _onWebPlayerStateChanged(stateStr, positionSec, durationSec);
        },
        onProgress: (positionSec, durationSec) {
          _onWebPlayerProgress(positionSec, durationSec);
        },
        onError: (errorStr) async {
          print('🔴 [AudioPlayerHandler] Web YouTube Player Error: $errorStr');
          if (kIsWeb && _usingWebIframe && currentYoutubeTrack != null) {
            print('🔄 [AudioPlayerHandler] YouTube IFrame failed ($errorStr). Falling back to direct stream player...');
            _usingWebIframe = false;
            final streamUrl = await _streamResolver.resolveStreamUrl(currentYoutubeTrack!.id);
            if (streamUrl != null) {
              await _player.setWebCrossOrigin(null);
              await _player.setAudioSource(AudioSource.uri(Uri.parse(streamUrl)));
              await _player.play();
              onStatusChanged?.call(isLoading: false, loadingTrackId: null, error: null);
              return;
            }
          }
          onStatusChanged?.call(
            isLoading: false,
            loadingTrackId: null,
            error: errorStr,
          );
        },
      );
    }
    _init();
    _startStallDetector();
    // Restore last session after a short delay to let everything initialize
    Future.delayed(const Duration(milliseconds: 1500), restoreLastSession);
  }

  void _onWebPlayerStateChanged(String? stateStr, double positionSec, double durationSec) {
    _webPosition = Duration(milliseconds: (positionSec * 1000).toInt());
    _webDuration = Duration(milliseconds: (durationSec * 1000).toInt());
    _webPositionController.add(_webPosition);
    _webDurationController.add(_webDuration);
    _webBufferedPositionController.add(_webPosition);

    switch (stateStr) {
      case 'idle':
        _webPlaying = false;
        _webProcessingState = AudioProcessingState.idle;
        _sessionTimer?.cancel();
        break;
      case 'buffering':
        _webPlaying = false;
        _webProcessingState = AudioProcessingState.buffering;
        break;
      case 'playing':
        _webPlaying = true;
        _webProcessingState = AudioProcessingState.ready;
        _startSessionTimer(); // Start periodic save on web
        break;
      case 'paused':
        _webPlaying = false;
        _webProcessingState = AudioProcessingState.ready;
        _sessionTimer?.cancel();
        _saveSession(); // Save immediately when paused on web
        break;
      case 'completed':
        _webPlaying = false;
        _webProcessingState = AudioProcessingState.completed;
        _sessionTimer?.cancel();
        break;
      default:
        _webProcessingState = AudioProcessingState.idle;
    }

    print('🛸 [AudioPlayerHandler] Web Player State sync: playing=$_webPlaying, state=$_webProcessingState, pos=$_webPosition, dur=$_webDuration');
    
    // Notify status changed loading states
    if (_webProcessingState == AudioProcessingState.buffering) {
      onStatusChanged?.call(
        isLoading: true,
        loadingTrackId: currentYoutubeTrack?.id,
        error: null,
      );
    } else {
      onStatusChanged?.call(
        isLoading: false,
        loadingTrackId: null,
        error: null,
      );
    }

    _updatePlaybackState();

    if (_webProcessingState == AudioProcessingState.completed) {
      print('🔄 [AudioPlayerHandler] Web Player completed. Auto-skipping to next...');
      if (currentYoutubeTrack != null) {
        onTrackComplete?.call(currentYoutubeTrack!);
      }
      skipToNext();
    }
  }

  void _onWebPlayerProgress(double positionSec, double durationSec) {
    _webPosition = Duration(milliseconds: (positionSec * 1000).toInt());
    _webDuration = Duration(milliseconds: (durationSec * 1000).toInt());
    _webPositionController.add(_webPosition);
    _webDurationController.add(_webDuration);
    _webBufferedPositionController.add(_webPosition);
  }

  void _updatePlaybackState() {
    final useIframe = kIsWeb && _usingWebIframe && !_playingOffline;
    final playing = useIframe ? _webPlaying : _player.playing;
    final state = useIframe ? _webProcessingState : (const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[_player.processingState] ?? AudioProcessingState.idle);

    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: state,
      playing: playing,
      updatePosition: useIframe ? _webPosition : _player.position,
      bufferedPosition: useIframe ? _webPosition : _player.bufferedPosition,
      speed: 1.0,
    ));
  }

  void _startStallDetector() {
    _stallTimer?.cancel();
    _stallTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (kIsWeb && _usingWebIframe && !_playingOffline) return;
      if (_player.playing) {
        final state = _player.processingState;
        if (state == ProcessingState.buffering || state == ProcessingState.loading) {
          // Slow internet, reset stall count and wait
          _stallCount = 0;
          _lastPosition = _player.position;
          return;
        }

        final currentPos = _player.position;
        if (_lastPosition != null && currentPos == _lastPosition) {
          _stallCount++;
          print('⚠️ [AudioPlayer] Stall detected! Count: $_stallCount/2 (Position: $currentPos, state: ${_player.processingState})');
          if (_stallCount >= 2) {
            print('🚨 [AudioPlayer] Player stalled/stopped for 8 seconds. Forcing stream recovery...');
            _stallCount = 0;
            if (currentYoutubeTrack != null) {
              playTrack(currentYoutubeTrack!, initialPosition: currentPos);
            }
          }
        } else {
          _stallCount = 0;
        }
        _lastPosition = currentPos;
      } else {
        _stallCount = 0;
        _lastPosition = null;
      }
    });
  }

  void _init() {
    _player.playbackEventStream.listen((PlaybackEvent event) {
      if (kIsWeb && _usingWebIframe && !_playingOffline) return;
      final playing = _player.playing;
      playbackState.add(playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[_player.processingState] ?? AudioProcessingState.idle,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: event.currentIndex,
      ));
    });

    _player.playbackEventStream.listen(
      (_) {},
      onError: (Object e, StackTrace st) {
        print('🔴 [AudioPlayer] Playback event error: $e');
        // Logging only. Recovery is handled strictly and safely by playTrack's local try-catch retry mechanism.
      },
    );

    // Listen for song completion to handle Autoplay
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        final pos = _player.position;
        final dur = _player.duration ?? Duration.zero;
        final diff = (dur - pos).inSeconds.abs();
        
        // If the duration is known and there is a significant premature gap (>15s), treat it as a network interruption
        if (dur.inSeconds > 0 && diff > 15) {
          print('⚠️ [AudioPlayer] Track interrupted prematurely (pos: $pos, dur: $dur, gap: $diff s). Re-establishing stream...');
          if (currentYoutubeTrack != null) {
            final wasPlaying = _player.playing;
            playTrack(currentYoutubeTrack!, initialPosition: pos, shouldPlay: wasPlaying);
          }
        } else {
          print('🔄 [AudioPlayer] Track completed normally. Autoplay skipping to next...');
          if (currentYoutubeTrack != null) {
            onTrackComplete?.call(currentYoutubeTrack!);
          }
          skipToNext();
        }
      }
    });

    _player.playerStateStream.listen((state) {
      print('🎵 [AudioPlayer] State: playing=${state.playing}, processingState=${state.processingState}');
      if (state.playing) {
        _startSessionTimer();
      } else {
        _sessionTimer?.cancel();
        // Save position immediately on pause
        _saveSession();
      }
    });
  }

  // ─── Session Persistence ───────────────────────────────────────────────────

  void _startSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _saveSession();
    });
  }

  Future<void> _saveSession() async {
    final track = currentYoutubeTrack;
    if (track == null || track.id.trim().isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('session_track_id', track.id);
      await prefs.setString('session_track_title', track.title);
      await prefs.setString('session_track_artist', track.artistName);
      if (track.artworkUrl != null) {
        await prefs.setString('session_track_artwork', track.artworkUrl!);
      }
      if (track.artistId != null) {
        await prefs.setString('session_track_artist_id', track.artistId!);
      }
      if (track.albumId != null) {
        await prefs.setString('session_track_album_id', track.albumId!);
      }
      if (track.albumName != null) {
        await prefs.setString('session_track_album_name', track.albumName!);
      }
      if (track.duration != null) {
        await prefs.setInt('session_track_duration_ms', track.duration!.inMilliseconds);
      }
      // On web, use _webPosition if using iframe; on native or direct stream, use _player.position
      final positionToSave = (kIsWeb && _usingWebIframe && !_playingOffline) ? _webPosition : _player.position;
      await prefs.setInt('session_position_ms', positionToSave.inMilliseconds);
      print('💾 [Session] Saved: "${track.title}" at ${positionToSave.inSeconds}s');
    } catch (e) {
      print('⚠️ [Session] Failed to save: $e');
    }
  }

  Future<void> restoreLastSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final trackId = prefs.getString('session_track_id');
      final title = prefs.getString('session_track_title');
      final artist = prefs.getString('session_track_artist');
      final positionMs = prefs.getInt('session_position_ms') ?? 0;
      final artworkUrl = prefs.getString('session_track_artwork');
      final durationMs = prefs.getInt('session_track_duration_ms');
      final artistId = prefs.getString('session_track_artist_id');
      final albumId = prefs.getString('session_track_album_id');
      final albumName = prefs.getString('session_track_album_name');

      if (trackId == null || trackId.trim().isEmpty || title == null || artist == null) {
        print('💾 [Session] No previous session found or invalid session track ID.');
        return;
      }

      print('💾 [Session] Restoring: "$title" at ${positionMs ~/ 1000}s');

      final track = YoutubeTrack(
        id: trackId,
        title: title,
        artistName: artist,
        artworkUrl: artworkUrl,
        artistId: artistId,
        albumId: albumId,
        albumName: albumName,
        duration: durationMs != null ? Duration(milliseconds: durationMs) : null,
      );

      final savedPosition = Duration(milliseconds: positionMs);

      // Store on handler fields first — so provider can read even if callback not wired yet
      lastRestoredTrack = track;
      lastRestoredPosition = savedPosition;

      // Notify the UI about the restored track so mini player is visible immediately
      onSessionRestored?.call(track, savedPosition);

      await playTrack(
        track,
        initialPosition: savedPosition,
        shouldPlay: false,
      );
    } catch (e) {
      print('⚠️ [Session] Failed to restore: $e');
    }
  }

  /// Cycles playback modes: Off -> Shuffle -> Repeat One -> Off
  void cyclePlaybackMode() {
    if (!isShuffleEnabled && !isLoopOneEnabled) {
      // Off -> Shuffle
      isShuffleEnabled = true;
      isLoopOneEnabled = false;
      _player.setShuffleModeEnabled(true);
      _player.setLoopMode(LoopMode.all);
      print('🔀 [PlaybackMode] Shuffle Enabled');
    } else if (isShuffleEnabled) {
      // Shuffle -> Repeat One
      isShuffleEnabled = false;
      isLoopOneEnabled = true;
      _player.setShuffleModeEnabled(false);
      _player.setLoopMode(LoopMode.one);
      print('🔂 [PlaybackMode] Loop One Enabled');
    } else {
      // Repeat One -> Off
      isShuffleEnabled = false;
      isLoopOneEnabled = false;
      _player.setShuffleModeEnabled(false);
      _player.setLoopMode(LoopMode.off);
      print('🔁 [PlaybackMode] Modes Disabled (Normal Playback)');
    }
    // Broadcast updated state
    playbackState.add(playbackState.value);
  }

  /// Play a dedicated playlist queue
  Future<void> playQueue(List<YoutubeTrack> tracks, {int initialIndex = 0}) async {
    if (tracks.isEmpty) return;
    queueList = List.from(tracks);
    currentIndex = initialIndex.clamp(0, queueList.length - 1);
    await playTrack(queueList[currentIndex]);
  }



  Future<void> playTrack(YoutubeTrack track, {Duration? initialPosition, bool shouldPlay = true}) async {
    if (track.id.trim().isEmpty) {
      print('⚠️ [playTrack] Ignored attempt to play track with empty/invalid ID');
      return;
    }
     if (currentYoutubeTrack != null && currentYoutubeTrack!.id != track.id) {
      final elapsed = (kIsWeb && _usingWebIframe && !_playingOffline) ? _webPosition : _player.position;
      final completed = (kIsWeb && _usingWebIframe && !_playingOffline)
          ? _webProcessingState == AudioProcessingState.completed
          : _player.processingState == ProcessingState.completed;
      if (!completed) {
        final total = (kIsWeb && _usingWebIframe && !_playingOffline) ? _webDuration : (_player.duration ?? track.duration ?? Duration.zero);
        onTrackSkip?.call(currentYoutubeTrack!, elapsed, total);
      }
    }
    print('▶️ [playTrack] START for: "${track.title}" (${track.id}) initialPosition: $initialPosition shouldPlay: $shouldPlay');
    SongRuntimeValidator.validateMetadata(track);
    if (currentYoutubeTrack?.id != track.id) {
      _retryCount = 0;
    }
    currentYoutubeTrack = track;
    onTrackStart?.call(track);



    // Maintain queue integrity
    if (queueList.isEmpty || !queueList.any((t) => t.id == track.id)) {
      queueList.add(track);
      currentIndex = queueList.length - 1;
    } else {
      currentIndex = queueList.indexWhere((t) => t.id == track.id);
    }

    // Auto-populate recommended "Up Next" songs in queue based on played track (like YT Music Radio)
    if (onFetchRecommendations != null) {
      Future.microtask(() async {
        try {
          final recommendations = await onFetchRecommendations!(track.id);
          if (recommendations.isNotEmpty) {
            // Remove previous recommended items that appear after our current track to refresh suggestions
            if (queueList.length > currentIndex + 1) {
              queueList.removeRange(currentIndex + 1, queueList.length);
            }
            
            // Append newly suggested tracks
            for (final rec in recommendations) {
              if (!queueList.any((t) => t.id == rec.id)) {
                queueList.add(rec);
              }
            }
            print('🟢 [Autoplay] Populated queue with ${recommendations.length} recommended tracks for "${track.title}"');
          }
        } catch (e) {
          print('⚠️ [Autoplay] Failed to fetch related queue tracks: $e');
        }
      });
    }

    onStatusChanged?.call(
      isLoading: true,
      loadingTrackId: track.id,
      error: null,
    );

    final item = MediaItem(
      id: track.id,
      title: track.title,
      artist: track.artistName,
      artUri: track.artworkUrl != null ? Uri.parse(track.artworkUrl!) : null,
      duration: track.duration,
    );
    mediaItem.add(item);

    // Check if song is downloaded offline in Hive (applies to both Web and mobile)
    bool hasOffline = false;
    try {
      final offlineBox = Hive.box('offline_audio_data');
      hasOffline = offlineBox.containsKey(track.id);
    } catch (_) {}

    if (hasOffline) {
      _playingOffline = true;
      try {
        print('💾 [playTrack] Found offline cache! Loading track from local database memory...');
        final dynamic data = Hive.box('offline_audio_data').get(track.id);
        if (data is List<int>) {
          await _player.pause();
          if (kIsWeb) {
            await _player.setWebCrossOrigin(null);
          }
          await _player.setAudioSource(_BufferAudioSource(data));
          
          onStatusChanged?.call(
            isLoading: false,
            loadingTrackId: null,
            error: null,
          );
          
          if (initialPosition != null && initialPosition > Duration.zero) {
            await _player.seek(initialPosition);
          }
          if (shouldPlay) {
            await _player.play();
          }
          return;
        }
      } catch (e) {
        print('⚠️ Failed to load track from offline cache: $e');
      }
    }

    _playingOffline = false;

    if (kIsWeb) {
      // 1. Prefer direct audio stream playback on Web (bypasses YouTube embed limits & works on Vercel)
      try {
        print('▶️ [playTrack Web] Resolving direct audio stream for: "${track.title}" (${track.id})...');
        final streamUrl = await _streamResolver.resolveStreamUrl(track.id);

        if (streamUrl != null && streamUrl.isNotEmpty) {
          _usingWebIframe = false;
          await _player.pause();
          await _player.setWebCrossOrigin(null);

          print('▶️ [playTrack Web] Loading stream in just_audio: $streamUrl');
          await _player.setAudioSource(
            AudioSource.uri(Uri.parse(streamUrl)),
          );

          if (initialPosition != null && initialPosition > Duration.zero) {
            await _player.seek(initialPosition);
          }

          onStatusChanged?.call(
            isLoading: false,
            loadingTrackId: null,
            error: null,
          );

          if (shouldPlay) {
            try {
              await _player.play();
            } catch (playErr) {
              print('⚠️ [playTrack Web] _player.play() failed ($playErr). Falling back to YouTube IFrame player...');
              throw playErr;
            }
          }
          return;
        } else {
          print('⚠️ [playTrack Web] Stream resolution returned null. Trying YouTube IFrame player fallback...');
        }
      } catch (e) {
        print('⚠️ [playTrack Web] Direct stream resolution/playback failed: $e. Trying YouTube IFrame fallback...');
      }

      // 2. Fallback to YouTube IFrame player if stream resolution fails
      try {
        _usingWebIframe = true;
        _webPosition = initialPosition ?? Duration.zero;
        _webPlaying = shouldPlay;
        _webProcessingState = AudioProcessingState.loading;
        _updatePlaybackState();

        print('▶️ [playTrack Web] YouTube IFrame load for: ${track.id} at ${_webPosition.inSeconds}s');
        _webPlayer.play(track.id, _webPosition.inSeconds);

        if (!shouldPlay) {
          Future.delayed(const Duration(milliseconds: 500), () {
            _webPlayer.pause();
          });
        }
        return;
      } catch (e) {
        print('🚨 [playTrack Web] Both direct stream and YouTube IFrame failed: $e');
        onStatusChanged?.call(
          isLoading: false,
          loadingTrackId: null,
          error: e.toString(),
        );
        return;
      }
    }

    try {
      print('▶️ [playTrack] Resolving stream URL...');
      final streamUrl = await _streamResolver.resolveStreamUrl(track.id);
      if (streamUrl == null) {
        print('🔴 [playTrack] Stream URL is null — all resolvers failed!');
        onStatusChanged?.call(
          isLoading: false,
          loadingTrackId: null,
          error: 'Could not find a playable stream for this song. Try another one.',
        );
        return;
      }

      final uri = Uri.tryParse(streamUrl);
      final isYouTubeUrl = uri != null &&
          (uri.host.contains('googlevideo.com') || uri.host.contains('youtube.com'));

      final clientType = uri?.queryParameters['c'] ?? 'WEB';
      final isAndroidClient = clientType.toUpperCase().startsWith('ANDROID');

      await _player.pause();

      final playUri = Uri.parse(streamUrl);
      print('▶️ [playTrack] Direct stream URI: $playUri');

      if (kIsWeb) {
        await _player.setWebCrossOrigin(null);
      }

      try {
        await _player.setAudioSource(
          AudioSource.uri(playUri),
        );
      } catch (e) {
        print('⚠️ [playTrack] Primary setAudioSource failed: $e. Attempting stream re-resolution fallback...');
        final fallbackUrl = await _streamResolver.resolveStreamUrl(track.id);
        if (fallbackUrl != null && fallbackUrl != streamUrl) {
          await _player.setAudioSource(
            AudioSource.uri(Uri.parse(fallbackUrl)),
          );
        } else {
          rethrow;
        }
      }

      if (initialPosition != null && initialPosition > Duration.zero) {
        print('🔄 [playTrack] Seeking to interruption position: $initialPosition');
        await _player.seek(initialPosition);
      }

      print('▶️ [playTrack] Audio source set. Starting playback: $shouldPlay');

      onStatusChanged?.call(
        isLoading: false,
        loadingTrackId: null,
        error: null,
      );

      if (shouldPlay) {
        await play();
      } else {
        await pause();
      }

      // Asynchronously fetch recommendations and append to active queue!
      // Skip on web — related video fetching uses youtube_explode_dart's watch-page
      // scraping which doesn't work reliably in the browser context.
      if (!kIsWeb) Future.microtask(() async {
        try {
          final video = await _streamResolver.yt.videos.get(track.id);
          final related = await _streamResolver.yt.videos.getRelatedVideos(video);
          if (related != null && related.isNotEmpty) {
            final suggestedTracks = related.whereType<Video>().map((v) {
              return YoutubeTrack(
                id: v.id.value,
                title: v.title,
                artistName: v.author,
                artworkUrl: v.thumbnails.highResUrl,
                duration: v.duration,
              );
            }).toList();

            for (final sugTrack in suggestedTracks) {
              if (!queueList.any((t) => t.id == sugTrack.id)) {
                queueList.add(sugTrack);
              }
            }
            print('📈 [AudioPlayer] Automatically appended ${suggestedTracks.length} recommendations to the active queue.');
          }
        } catch (err) {
          print('⚠️ [AudioPlayer] Failed to load auto-recommendations: $err');
        }
      });
    } catch (e, stack) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('interrupted') || errStr.contains('abort') || errStr.contains('interruption')) {
        print('🟡 [playTrack] Load cancelled by subsequent request — ignoring.');
        return;
      }

      print('\n');
      print('======================================================================');
      print('🚨🚨🚨 [AUDIO PLAYBACK SYSTEM ERROR] 🚨🚨🚨');
      print('======================================================================');
      print('TRACK ID: ${track.id}');
      print('TRACK TITLE: ${track.title}');
      print('TRACK ARTIST: ${track.artistName}');
      print('ERROR DETAILS:');
      print(e.toString());
      print('STACK TRACE:');
      print(stack.toString());
      print('======================================================================');
      print('\n');

      onStatusChanged?.call(
        isLoading: false,
        loadingTrackId: null,
        error: 'Playback failed: ${e.toString().split('\n').first}',
      );

      // Attempt recovery retry loop on network error up to 3 times
      if (_retryCount < 3) {
        _retryCount++;
        print('🔄 [playTrack] Attempting stream recovery retry ($_retryCount/3) in 3 seconds...');
        Future.delayed(const Duration(seconds: 3), () {
          if (currentYoutubeTrack?.id == track.id) {
            playTrack(track, initialPosition: _player.position, shouldPlay: shouldPlay);
          }
        });
      } else {
        print('🔴 [playTrack] Max retries reached (3/3). Stopping playback recovery.');
        onStatusChanged?.call(
          isLoading: false,
          loadingTrackId: null,
          error: 'Playback failed after multiple attempts: ${e.toString().split('\n').first}',
        );
      }
    }
  }

  @override
  Future<void> play() async {
    if (kIsWeb && _usingWebIframe && !_playingOffline) {
      _webPlayer.resume();
      _webPlaying = true;
      _updatePlaybackState();
    } else {
      await _player.play();
    }
  }

  @override
  Future<void> pause() async {
    if (kIsWeb && _usingWebIframe && !_playingOffline) {
      _webPlayer.pause();
      _webPlaying = false;
      _updatePlaybackState();
    } else {
      await _player.pause();
    }
  }

  @override
  Future<void> seek(Duration position) async {
    if (kIsWeb && _usingWebIframe && !_playingOffline) {
      _webPlayer.seek(position.inSeconds);
      _webPosition = position;
      _webPositionController.add(_webPosition);
      _updatePlaybackState();
    } else {
      await _player.seek(position);
    }
  }

  @override
  Future<void> skipToNext() async {
    if (isLoopOneEnabled) {
      await seek(Duration.zero);
      await play();
      return;
    }
    if (queueList.isEmpty) return;
    if (isShuffleEnabled) {
      final random = DateTime.now().millisecondsSinceEpoch % queueList.length;
      currentIndex = random;
    } else {
      if (currentIndex < queueList.length - 1) {
        currentIndex++;
      } else {
        currentIndex = 0; // Wrap around to start of playlist
      }
    }
    await playTrack(queueList[currentIndex]);
  }

  @override
  Future<void> skipToPrevious() async {
    if (queueList.isEmpty) return;
    if (currentIndex > 0) {
      currentIndex--;
    } else {
      currentIndex = queueList.length - 1; // Wrap around to end
    }
    await playTrack(queueList[currentIndex]);
  }

  @override
  Future<void> stop() async {
    _stallTimer?.cancel();
    _sessionTimer?.cancel();
    await _saveSession();
    if (kIsWeb && _usingWebIframe && !_playingOffline) {
      _webPlayer.stop();
      _webPlaying = false;
      _webProcessingState = AudioProcessingState.idle;
      _updatePlaybackState();
    } else {
      await _player.stop();
    }
    return super.stop();
  }
}

class _BufferAudioSource extends StreamAudioSource {
  final List<int> _bytes;
  _BufferAudioSource(this._bytes);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _bytes.length;
    return StreamAudioResponse(
      sourceLength: _bytes.length,
      contentLength: end - start,
      offset: start,
      contentType: 'audio/mpeg',
      stream: Stream.value(_bytes.sublist(start, end)),
    );
  }
}
