import 'package:flutter_test/flutter_test.dart';
import 'package:dart_ytmusic_api/yt_music.dart';
import 'package:musicplayer/features/youtube/data/repositories/ytmusic_repository.dart';
import 'package:musicplayer/features/youtube/data/models/youtube_track.dart';
import 'package:musicplayer/features/youtube/data/services/song_runtime_validator.dart';

void main() {
  test('Test search songs pipeline', () async {
    final ytMusic = YTMusic();
    ytMusic.config = {
      'INNERTUBE_API_KEY': 'AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30',
      'INNERTUBE_API_VERSION': 'v1',
      'INNERTUBE_CLIENT_NAME': 'WEB_REMIX',
      'INNERTUBE_CLIENT_VERSION': '1.20260526.04.00',
      'GL': 'IN',
      'HL': 'en',
    };
    ytMusic.hasInitialized = true;
    final repo = YTMusicRepository(ytMusic);

    final queries = ['shape of you', 'arijit singh', 'taylor swift'];

    for (final q in queries) {
      print('\n=== Query: "$q" ===');
      final raw = await repo.searchSongs(q);
      print('Raw tracks count: ${raw.length}');
      final validated = SongRuntimeValidator.validateAndFilterList(raw, source: q);
      print('Validated tracks count: ${validated.length}');
      expect(validated, isNotEmpty);
      for (var i = 0; i < (validated.length < 3 ? validated.length : 3); i++) {
        print('  [$i] ${validated[i].title} - ${validated[i].artistName} (art: ${validated[i].artworkUrl})');
      }
    }
  });
}
