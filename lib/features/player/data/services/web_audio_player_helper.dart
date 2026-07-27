import 'web_audio_player_stub.dart'
    if (dart.library.js) 'web_audio_player_web.dart';

abstract class WebAudioPlayerHelper {
  factory WebAudioPlayerHelper() => getWebAudioPlayerHelper();

  void initWebListeners({
    required void Function(String? stateStr, double positionSec, double durationSec) onStateChange,
    required void Function(double positionSec, double durationSec) onProgress,
    required void Function(String errorStr) onError,
  });

  void play(String videoId, int startSeconds);
  void pause();
  void resume();
  void seek(int seconds);
  void stop();
}
