/// Core constants for API endpoints and configuration.
class ApiConstants {
  ApiConstants._();

  // ── Spotify credentials ───────────────────────────────────────────────────
  static const String spotifyClientId = 'aea423c880c34671895c36c1e2e371b4';

  // ── Spotify endpoints ─────────────────────────────────────────────────────
  static const String spotifyBaseUrl = 'https://api.spotify.com/v1';
  static const String spotifyAuthUrl = 'https://accounts.spotify.com/authorize';
  static const String spotifyTokenUrl =
      'https://accounts.spotify.com/api/token';

  // Redirect URI (must be whitelisted in Spotify Dashboard)
  static const String spotifyRedirectScheme = 'musicplayer';
  static const String spotifyRedirectUri = 'musicplayer://callback';

  // ── Spotify scopes ────────────────────────────────────────────────────────
  static const List<String> spotifyScopes = [
    'user-read-private',
    'user-read-email',
    'user-library-read',
    'user-top-read',
    'user-read-recently-played',
    'playlist-read-private',
    'playlist-read-collaborative',
    'user-read-playback-state',
    'user-modify-playback-state',
  ];

  // ── YouTube search query patterns (ordered by preference) ─────────────────
  static const List<String> youtubeSearchPatterns = [
    '{artist} - {title} official audio',
    '{artist} {title} audio',
    '{artist} - {title}',
  ];
}
