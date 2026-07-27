import 'web_audio_player_helper.dart';

WebAudioPlayerHelper getWebAudioPlayerHelper() => WebAudioPlayerStub();

class WebAudioPlayerStub implements WebAudioPlayerHelper {
  @override
  void initWebListeners({
    required void Function(String? stateStr, double positionSec, double durationSec) onStateChange,
    required void Function(double positionSec, double durationSec) onProgress,
    required void Function(String errorStr) onError,
  }) {
    // No-op on native platforms
  }

  @override
  void play(String videoId, int startSeconds) {
    // No-op on native platforms
  }

  @override
  void pause() {
    // No-op on native platforms
  }

  @override
  void resume() {
    // No-op on native platforms
  }

  @override
  void seek(int seconds) {
    // No-op on native platforms
  }

  @override
  void stop() {
    // No-op on native platforms
  }
}
