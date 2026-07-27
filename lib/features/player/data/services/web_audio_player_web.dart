import 'dart:js' as js;
import 'dart:html' as html;
import 'web_audio_player_helper.dart';

WebAudioPlayerHelper getWebAudioPlayerHelper() => WebAudioPlayerWeb();

class WebAudioPlayerWeb implements WebAudioPlayerHelper {
  @override
  void initWebListeners({
    required void Function(String? stateStr, double positionSec, double durationSec) onStateChange,
    required void Function(double positionSec, double durationSec) onProgress,
    required void Function(String errorStr) onError,
  }) {
    // Listen to YouTube player state events from JavaScript
    html.window.addEventListener('yt-player-state', (html.Event event) {
      final customEvent = event as html.CustomEvent;
      final detail = customEvent.detail;
      if (detail == null) return;
      
      final stateStr = detail['state'] as String?;
      final positionSec = (detail['position'] as num?)?.toDouble() ?? 0.0;
      final durationSec = (detail['duration'] as num?)?.toDouble() ?? 0.0;
      
      onStateChange(stateStr, positionSec, durationSec);
    });

    // Listen to YouTube player progress ticks from JavaScript
    html.window.addEventListener('yt-player-progress', (html.Event event) {
      final customEvent = event as html.CustomEvent;
      final detail = customEvent.detail;
      if (detail == null) return;
      
      final positionSec = (detail['position'] as num?)?.toDouble() ?? 0.0;
      final durationSec = (detail['duration'] as num?)?.toDouble() ?? 0.0;
      
      onProgress(positionSec, durationSec);
    });

    // Listen to YouTube player error events from JavaScript
    html.window.addEventListener('yt-player-error', (html.Event event) {
      final customEvent = event as html.CustomEvent;
      final detail = customEvent.detail;
      if (detail == null) return;
      
      final errorStr = detail['error'] as String? ?? 'Unknown YouTube error';
      onError(errorStr);
    });
  }

  @override
  void play(String videoId, int startSeconds) {
    js.context.callMethod('playYT', [videoId, startSeconds]);
  }

  @override
  void pause() {
    js.context.callMethod('pauseYT');
  }

  @override
  void resume() {
    js.context.callMethod('resumeYT');
  }

  @override
  void seek(int seconds) {
    js.context.callMethod('seekYT', [seconds]);
  }

  @override
  void stop() {
    js.context.callMethod('stopYT');
  }
}
