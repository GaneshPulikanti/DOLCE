import 'package:flutter/foundation.dart';
import '../models/youtube_track.dart';
import '../../../player/data/services/youtube_stream_resolver.dart';

class SongValidationResult {
  final bool isValid;
  final String trackId;
  final String title;
  final String artist;
  final String? streamUrl;
  final List<String> issues;

  SongValidationResult({
    required this.isValid,
    required this.trackId,
    required this.title,
    required this.artist,
    this.streamUrl,
    this.issues = const [],
  });

  @override
  String toString() {
    final status = isValid ? '✅ PASS' : '❌ FAIL';
    return '''
======================================================================
📊 RUNTIME SONG VALIDATION REPORT: $status
----------------------------------------------------------------------
🎵 Track ID     : $trackId
📌 Title        : $title
👤 Artist       : $artist
🔊 Stream URL   : ${streamUrl ?? "None (Metadata only)"}
⚠️ Issues       : ${issues.isEmpty ? "None" : issues.join(', ')}
======================================================================
''';
  }
}

class SongRuntimeValidator {
  static final _streamResolver = YoutubeStreamResolver();

  /// Validates a single track's metadata for runtime completeness.
  static SongValidationResult validateMetadata(YoutubeTrack track) {
    final issues = <String>[];

    if (track.id.trim().isEmpty) {
      issues.add('Empty or null track ID');
    }
    if (track.title.trim().isEmpty) {
      issues.add('Empty title');
    }
    if (track.artistName.trim().isEmpty) {
      issues.add('Empty artist name');
    }
    if (track.artworkUrl == null || track.artworkUrl!.trim().isEmpty) {
      issues.add('Missing artwork URL');
    }

    final isValid = issues.isEmpty;
    final result = SongValidationResult(
      isValid: isValid,
      trackId: track.id,
      title: track.title,
      artist: track.artistName,
      issues: issues,
    );

    if (kDebugMode) {
      print(result.toString());
    }

    return result;
  }

  /// Validates a list of tracks metadata returned from search or home feed.
  static List<YoutubeTrack> validateAndFilterList(List<YoutubeTrack> tracks, {required String source}) {
    final validTracks = <YoutubeTrack>[];
    int failedCount = 0;

    for (final track in tracks) {
      final res = validateMetadata(track);
      if (res.isValid) {
        validTracks.add(track);
      } else {
        failedCount++;
        print('⚠️ [RuntimeValidator] Dropping invalid track from $source: ${res.issues.join(", ")}');
      }
    }

    print('🟢 [RuntimeValidator] Source "$source": ${validTracks.length} valid tracks, $failedCount dropped.');
    return validTracks;
  }

  /// Validates audio stream URL playability for a given track at runtime.
  static Future<SongValidationResult> validateStreamPlayback(YoutubeTrack track) async {
    final metaRes = validateMetadata(track);
    if (!metaRes.isValid) return metaRes;

    try {
      final streamUrl = await _streamResolver.resolveStreamUrl(track.id);
      final hasUrl = streamUrl != null && streamUrl.isNotEmpty;

      final issues = <String>[];
      if (!hasUrl) {
        issues.add('Failed to resolve playable audio stream URL');
      }

      final result = SongValidationResult(
        isValid: hasUrl,
        trackId: track.id,
        title: track.title,
        artist: track.artistName,
        streamUrl: streamUrl,
        issues: issues,
      );

      print(result.toString());
      return result;
    } catch (e) {
      final result = SongValidationResult(
        isValid: false,
        trackId: track.id,
        title: track.title,
        artist: track.artistName,
        issues: ['Stream resolution exception: $e'],
      );
      print(result.toString());
      return result;
    }
  }
}
