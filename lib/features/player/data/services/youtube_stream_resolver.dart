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
    // androidVr also works well for web.
    final List<List<YoutubeApiClient>> clientStrategies = kIsWeb
        ? [
            [YoutubeApiClient.androidSdkless],
            [YoutubeApiClient.androidVr],
            [YoutubeApiClient.ios],
            [YoutubeApiClient.mweb],
          ]
        : [
            [YoutubeApiClient.androidVr],
            [YoutubeApiClient.android],
            [YoutubeApiClient.tv],
            [YoutubeApiClient.ios],
            [YoutubeApiClient.mweb],
            [YoutubeApiClient.mediaConnect],
          ];

    for (final clients in clientStrategies) {
      try {
        final clientName = clients.toString();
        print('🟡 [StreamResolver] Trying client: $clientName for $videoId...');
        final StreamManifest manifest = await yt.videos.streamsClient.getManifest(
          videoId,
          ytClients: clients,
          // On web: skip the watch page fetch entirely. The watch page is fetched
          // through our CORS proxy which modifies the HTML and breaks the JS parser,
          // causing "Unexpected null value". Android clients use the InnerTube API
          // directly and don't need the watch page for stream URL resolution.
          requireWatchPage: !kIsWeb,
        );

        final audioStreams = manifest.audioOnly;
        if (audioStreams.isEmpty) {
          print('⚠️ [StreamResolver] No audio streams from $clientName');
          continue;
        }

        // Prefer MP4/M4A for native player compatibility
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
      } catch (e, s) {
        print('⚠️ [StreamResolver] Client ${clients} failed for $videoId: $e\n$s');
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
    final staticInstances = [
      'https://inv.thepixora.com',
      'https://invidious.slipfox.xyz',
      'https://invidious.flokinet.to',
      'https://invidious.projectsegfault.com',
      'https://yt.cdaut.de',
      'https://invidious.nerdvpn.de',
    ];

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

    final client = http.Client();

    // Try all static instances — request with local parameter based on platform
    for (final instance in staticInstances) {
      try {
        final uri = Uri.parse('$instance/api/v1/videos/$videoId?local=$localParam');
        print('🟡 [StreamResolver] Trying Invidious: $instance (local=$localParam)');
        final res = await client.get(uri).timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final data = json.decode(res.body) as Map<String, dynamic>;
          final rawUrl = tryExtractAudioUrl(data, instance);
          if (rawUrl != null) {
            final normalizedUrl = _normalizeStreamUrl(rawUrl);
            final c = Uri.tryParse(rawUrl)?.queryParameters['c'] ?? 'proxy';
            print('🟢 [StreamResolver] Invidious resolved! instance=$instance c=$c url=${rawUrl.substring(0, 60)}...');
            client.close();
            return normalizedUrl;
          }
        } else {
          print('⚠️ [StreamResolver] Invidious $instance returned HTTP ${res.statusCode}');
        }
      } catch (e) {
        print('⚠️ [StreamResolver] Invidious $instance failed: $e');
      }
    }

    // Dynamic directory fallback
    try {
      print('🟡 [StreamResolver] Querying dynamic Invidious directory...');
      final listRes = await client
          .get(Uri.parse('https://api.invidious.io/instances.json?sort_by=health'))
          .timeout(const Duration(seconds: 5));
      if (listRes.statusCode == 200) {
        final listData = json.decode(listRes.body) as List<dynamic>;
        final freshInstances = listData
            .map((i) => i[1])
            .where((i) => i['type'] == 'https' && i['api'] == true && i['cors'] == true)
            .map((i) => i['uri'] as String)
            .toList();

        for (final instance in freshInstances.take(6)) {
          try {
            final uri = Uri.parse('$instance/api/v1/videos/$videoId?local=$localParam');
            final res = await client.get(uri).timeout(const Duration(seconds: 6));
            if (res.statusCode == 200) {
              final data = json.decode(res.body) as Map<String, dynamic>;
              final rawUrl = tryExtractAudioUrl(data, instance);
              if (rawUrl != null) {
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

    client.close();
    print('🔴 [StreamResolver] All Invidious instances failed for $videoId');
    return null;
  }


  void dispose() {
    yt.close();
  }
}
