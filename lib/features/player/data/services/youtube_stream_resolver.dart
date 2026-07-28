import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:youtube_explode_dart/src/reverse_engineering/youtube_http_client.dart';

/// Custom YouTube HTTP client that mocks successful HEAD requests on web
/// to bypass CORS preflight errors during stream client strategy verification.
class WebYoutubeHttpClient extends YoutubeHttpClient {
  WebYoutubeHttpClient([super.httpClient]);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (kIsWeb && request.method.toUpperCase() == 'HEAD') {
      final url = request.url.toString();
      if (url.contains('googlevideo.com') || url.contains('videoplayback')) {
        print('🛸 [WebHttpClient] Mocking successful HEAD request to bypass CORS preflight: $url');
        return http.StreamedResponse(
          Stream.value([]),
          200,
          headers: {
            'content-length': '10000000', // dummy content length
            'accept-ranges': 'bytes',
          },
          request: request,
        );
      }
    }
    return super.send(request);
  }
}

/// Resolves audio streams from YouTube using youtube_explode_dart and robust Invidious backups.
class YoutubeStreamResolver {
  final YoutubeHttpClient httpClient;
  final YoutubeExplode yt;

  YoutubeStreamResolver()
      : httpClient = kIsWeb ? WebYoutubeHttpClient() : YoutubeHttpClient(),
        yt = YoutubeExplode(httpClient: kIsWeb ? WebYoutubeHttpClient() : YoutubeHttpClient());

  /// Resolves the best audio stream info for a given [videoId].
  ///
  /// On web: uses androidSdkless/androidVr with requireWatchPage:false so the
  /// CORS proxy is only used for the InnerTube player API (not the watch page).
  /// This avoids the "Unexpected null value" crash when the proxy mangles the HTML.
  Future<AudioOnlyStreamInfo?> resolveAudioStream(String videoId) async {
    // On web, prefer clients that don't require cipher decryption and work via CORS proxy.
    // androidSdkless provides direct URLs (no svpuc server-side auth issues).
    final List<Map<String, dynamic>> clientStrategies = kIsWeb
        ? [
            {'clients': [YoutubeApiClient.androidVr], 'requireWatchPage': false},
            {'clients': [YoutubeApiClient.androidSdkless], 'requireWatchPage': false},
            {'clients': [YoutubeApiClient.tv], 'requireWatchPage': false},
            {'clients': [YoutubeApiClient.ios], 'requireWatchPage': true},
            {'clients': [YoutubeApiClient.mweb], 'requireWatchPage': true},
          ]
        : [
            {'clients': [YoutubeApiClient.androidVr], 'requireWatchPage': false},
            {'clients': [YoutubeApiClient.android], 'requireWatchPage': false},
            {'clients': [YoutubeApiClient.tv], 'requireWatchPage': false},
            {'clients': [YoutubeApiClient.ios], 'requireWatchPage': true},
            {'clients': [YoutubeApiClient.mweb], 'requireWatchPage': true},
          ];

    for (final strategy in clientStrategies) {
      final clients = strategy['clients'] as List<YoutubeApiClient>;
      final reqWatch = strategy['requireWatchPage'] as bool;
      try {
        final clientName = clients.toString();
        print('🟡 [StreamResolver] Trying client strategy: $clientName (requireWatchPage=$reqWatch) for $videoId...');
        final StreamManifest manifest = await yt.videos.streamsClient.getManifest(
          videoId,
          ytClients: clients,
          requireWatchPage: reqWatch,
        );

        final audioStreams = manifest.audioOnly;
        if (audioStreams.isEmpty) {
          print('⚠️ [StreamResolver] No audio streams from $clientName');
          continue;
        }

        // Prefer MP4/M4A for native player & web compatibility
        final mp4Streams = audioStreams.where(
          (s) => s.container.name == 'mp4' || s.container.name == 'm4a',
        );

        final AudioOnlyStreamInfo selectedStream = mp4Streams.isNotEmpty
            ? mp4Streams.withHighestBitrate()
            : audioStreams.withHighestBitrate();

        final urlStr = selectedStream.url.toString();
        final clientInUrl = Uri.parse(urlStr).queryParameters['c'] ?? '?';
        print('🟢 [StreamResolver] Resolved via $clientName! Bitrate: ${selectedStream.bitrate} | URL client: c=$clientInUrl');
        return selectedStream;
      } catch (e) {
        print('⚠️ [StreamResolver] Strategy $clients (watchPage=$reqWatch) failed for $videoId: $e');
      }
    }

    print('🔴 [StreamResolver] ALL native strategies failed for $videoId');
    return null;
  }


  /// Backwards-compatible fallback that resolves a stream URL string.
  /// Tries native youtube_explode_dart clients FIRST (direct YouTube CDN),
  /// and falls back to Invidious if rate-limited or blocked.
  Future<String?> resolveStreamUrl(String videoId) async {
    // 1. Try native youtube_explode_dart clients first (direct YouTube CDN)
    final stream = await resolveAudioStream(videoId);
    if (stream != null) return _normalizeStreamUrl(stream.url.toString());

    // 2. Fallback to Invidious if native strategies fail
    final invidiousUrl = await _resolveInvidiousStream(videoId);
    if (invidiousUrl != null) return invidiousUrl;

    return null;
  }

  String _normalizeStreamUrl(String url) {
    // Force HTTPS — Invidious sometimes returns http:// URLs which browsers
    // reject as mixed content when the app is served over https or localhost.
    if (url.startsWith('http://')) {
      url = 'https://' + url.substring(7);
      print('🔀 [StreamResolver] Normalized stream URL to HTTPS: ${url.substring(0, 60)}...');
    }

    return url;
  }

  /// Extremely robust backup stream resolver that queries healthy public Invidious instances
  /// to fetch completely unblocked audio stream URLs.
  /// On Web: requests local=false so Invidious returns direct YouTube CDN (googlevideo.com) URLs,
  /// which browser <audio> elements play directly without CORS proxy limits or mixed content blocks.
  /// On Native: requests local=true so Invidious returns its own proxied URLs for IP robustness.
  Future<String?> _resolveInvidiousStream(String videoId) async {
    print('🟡 [StreamResolver] Trying Invidious API for $videoId...');
    
    final client = http.Client();
    final localParam = kIsWeb ? 'false' : 'true';

    int parseBitrate(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    String? tryExtractAudioUrl(Map<String, dynamic> data, String instance) {
      final adaptive = data['adaptiveFormats'] as List<dynamic>?;
      if (adaptive == null) return null;
      final audio = adaptive
          .where((s) => s['type']?.toString().contains('audio') == true)
          .toList();
      if (audio.isEmpty) return null;
      audio.sort((a, b) => parseBitrate(b['bitrate']).compareTo(parseBitrate(a['bitrate'])));
      return audio.first['url'] as String?;
    }

    // 1. First try dynamic directory of currently healthy Invidious instances
    try {
      print('🟡 [StreamResolver] Querying dynamic Invidious directory for healthy nodes...');
      final listRes = await client
          .get(Uri.parse('https://api.invidious.io/instances.json?sort_by=health'))
          .timeout(const Duration(seconds: 4));
      if (listRes.statusCode == 200) {
        final listData = json.decode(listRes.body) as List<dynamic>;
        final freshInstances = listData
            .map((i) => i[1])
            .where((i) => i['type'] == 'https' && i['api'] == true)
            .map((i) => i['uri'] as String)
            .toList();

        for (final instance in freshInstances.take(8)) {
          try {
            final uri = Uri.parse('$instance/api/v1/videos/$videoId?local=$localParam');
            final res = await client.get(uri).timeout(const Duration(seconds: 4));
            if (res.statusCode == 200) {
              final data = json.decode(res.body) as Map<String, dynamic>;
              final rawUrl = tryExtractAudioUrl(data, instance);
              if (rawUrl != null && rawUrl.isNotEmpty) {
                final normalizedUrl = _normalizeStreamUrl(rawUrl);
                print('🟢 [StreamResolver] Dynamic Invidious resolved! instance=$instance');
                client.close();
                return normalizedUrl;
              }
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      print('⚠️ [StreamResolver] Dynamic Invidious directory failed: $e');
    }

    // 2. Static backup instances
    final staticInstances = [
      'https://yewtu.be',
      'https://inv.nadeko.net',
      'https://invidious.drgns.space',
      'https://invidious.nerdvpn.de',
      'https://invidious.privacydev.net',
      'https://inv.tux.stream',
    ];

    for (final instance in staticInstances) {
      try {
        final uri = Uri.parse('$instance/api/v1/videos/$videoId?local=$localParam');
        print('🟡 [StreamResolver] Trying static Invidious: $instance (local=$localParam)');
        final res = await client.get(uri).timeout(const Duration(seconds: 5));
        if (res.statusCode == 200) {
          final data = json.decode(res.body) as Map<String, dynamic>;
          final rawUrl = tryExtractAudioUrl(data, instance);
          if (rawUrl != null && rawUrl.isNotEmpty) {
            final normalizedUrl = _normalizeStreamUrl(rawUrl);
            print('🟢 [StreamResolver] Static Invidious resolved! instance=$instance');
            client.close();
            return normalizedUrl;
          }
        }
      } catch (e) {
        print('⚠️ [StreamResolver] Invidious $instance failed: $e');
      }
    }

    client.close();
    print('🔴 [StreamResolver] All Invidious instances failed for $videoId');
    return null;
  }


  void dispose() {
    yt.close();
  }
}
