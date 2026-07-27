/// Application-wide constants for timeouts, cache, and retry logic.
class AppConstants {
  AppConstants._();

  // Network
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
  static const int maxRetries = 3;

  // Cache
  static const Duration streamUrlCacheDuration = Duration(hours: 5);
  static const Duration metadataCacheDuration = Duration(minutes: 30);

  // Player
  static const Duration positionUpdateInterval = Duration(milliseconds: 300);
  static const Duration seekDebounce = Duration(milliseconds: 100);

  // Search
  static const Duration searchDebounce = Duration(milliseconds: 400);
  static const int searchResultLimit = 20;

  // UI
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration animationDurationSlow = Duration(milliseconds: 500);
  static const Duration animationDurationFast = Duration(milliseconds: 150);
}
