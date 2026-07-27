class UserPreferenceProfile {
  final List<String> languages;
  final List<String> artists;
  final List<String> genres;
  final DateTime createdAt;

  UserPreferenceProfile({
    required this.languages,
    required this.artists,
    required this.genres,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'languages': languages,
        'artists': artists,
        'genres': genres,
        'createdAt': createdAt.toIso8601String(),
      };

  factory UserPreferenceProfile.fromJson(Map<String, dynamic> json) {
    return UserPreferenceProfile(
      languages: List<String>.from(json['languages'] ?? []),
      artists: List<String>.from(json['artists'] ?? []),
      genres: List<String>.from(json['genres'] ?? []),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }
}

class TasteProfile {
  final Map<String, int> artistPlays;
  final Map<String, int> songPlays;
  final Map<String, int> artistSearches;
  final Map<String, int> skips;
  final Map<String, int> favorites;
  final DateTime lastUpdated;

  TasteProfile({
    required this.artistPlays,
    required this.songPlays,
    required this.artistSearches,
    required this.skips,
    required this.favorites,
    required this.lastUpdated,
  });

  Map<String, dynamic> toJson() => {
        'artistPlays': artistPlays,
        'songPlays': songPlays,
        'artistSearches': artistSearches,
        'skips': skips,
        'favorites': favorites,
        'lastUpdated': lastUpdated.toIso8601String(),
      };

  factory TasteProfile.fromJson(Map<String, dynamic> json) {
    return TasteProfile(
      artistPlays: Map<String, int>.from(json['artistPlays'] ?? {}),
      songPlays: Map<String, int>.from(json['songPlays'] ?? {}),
      artistSearches: Map<String, int>.from(json['artistSearches'] ?? {}),
      skips: Map<String, int>.from(json['skips'] ?? {}),
      favorites: Map<String, int>.from(json['favorites'] ?? {}),
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'])
          : DateTime.now(),
    );
  }

  factory TasteProfile.empty() {
    return TasteProfile(
      artistPlays: {},
      songPlays: {},
      artistSearches: {},
      skips: {},
      favorites: {},
      lastUpdated: DateTime.now(),
    );
  }

  TasteProfile copyWith({
    Map<String, int>? artistPlays,
    Map<String, int>? songPlays,
    Map<String, int>? artistSearches,
    Map<String, int>? skips,
    Map<String, int>? favorites,
    DateTime? lastUpdated,
  }) {
    return TasteProfile(
      artistPlays: artistPlays ?? this.artistPlays,
      songPlays: songPlays ?? this.songPlays,
      artistSearches: artistSearches ?? this.artistSearches,
      skips: skips ?? this.skips,
      favorites: favorites ?? this.favorites,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

class UserMusicProfile {
  final Map<String, double> artistScores;
  final Map<String, double> genreScores;
  final Map<String, double> languageScores;
  final Map<String, double> playlistThemeScores;
  
  // v4.1 Track-Centric Properties
  final Map<String, double> trackScores;
  final Map<String, int> trackPlays;
  final Map<String, int> trackCompletions;

  // v4.1 Fatigue Properties
  final Map<String, int> artistImpressions;
  final Map<String, int> artistClicks;

  final int totalPlays;
  final int totalLikes;
  final int totalSkips;

  final DateTime lastUpdated;

  UserMusicProfile({
    required this.artistScores,
    required this.genreScores,
    required this.languageScores,
    required this.playlistThemeScores,
    required this.trackScores,
    required this.trackPlays,
    required this.trackCompletions,
    required this.artistImpressions,
    required this.artistClicks,
    required this.totalPlays,
    required this.totalLikes,
    required this.totalSkips,
    required this.lastUpdated,
  });

  Map<String, dynamic> toJson() => {
        'artistScores': artistScores,
        'genreScores': genreScores,
        'languageScores': languageScores,
        'playlistThemeScores': playlistThemeScores,
        'trackScores': trackScores,
        'trackPlays': trackPlays,
        'trackCompletions': trackCompletions,
        'artistImpressions': artistImpressions,
        'artistClicks': artistClicks,
        'totalPlays': totalPlays,
        'totalLikes': totalLikes,
        'totalSkips': totalSkips,
        'lastUpdated': lastUpdated.toIso8601String(),
      };

  factory UserMusicProfile.fromJson(Map<String, dynamic> json) {
    return UserMusicProfile(
      artistScores: Map<String, double>.from(
          (json['artistScores'] ?? {}).map((k, v) => MapEntry(k, (v as num).toDouble()))),
      genreScores: Map<String, double>.from(
          (json['genreScores'] ?? {}).map((k, v) => MapEntry(k, (v as num).toDouble()))),
      languageScores: Map<String, double>.from(
          (json['languageScores'] ?? {}).map((k, v) => MapEntry(k, (v as num).toDouble()))),
      playlistThemeScores: Map<String, double>.from(
          (json['playlistThemeScores'] ?? {}).map((k, v) => MapEntry(k, (v as num).toDouble()))),
      trackScores: Map<String, double>.from(
          (json['trackScores'] ?? {}).map((k, v) => MapEntry(k, (v as num).toDouble()))),
      trackPlays: Map<String, int>.from(json['trackPlays'] ?? {}),
      trackCompletions: Map<String, int>.from(json['trackCompletions'] ?? {}),
      artistImpressions: Map<String, int>.from(json['artistImpressions'] ?? {}),
      artistClicks: Map<String, int>.from(json['artistClicks'] ?? {}),
      totalPlays: json['totalPlays'] as int? ?? 0,
      totalLikes: json['totalLikes'] as int? ?? 0,
      totalSkips: json['totalSkips'] as int? ?? 0,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'])
          : DateTime.now(),
    );
  }

  factory UserMusicProfile.empty() {
    return UserMusicProfile(
      artistScores: {},
      genreScores: {},
      languageScores: {},
      playlistThemeScores: {},
      trackScores: {},
      trackPlays: {},
      trackCompletions: {},
      artistImpressions: {},
      artistClicks: {},
      totalPlays: 0,
      totalLikes: 0,
      totalSkips: 0,
      lastUpdated: DateTime.now(),
    );
  }

  UserMusicProfile copyWith({
    Map<String, double>? artistScores,
    Map<String, double>? genreScores,
    Map<String, double>? languageScores,
    Map<String, double>? playlistThemeScores,
    Map<String, double>? trackScores,
    Map<String, int>? trackPlays,
    Map<String, int>? trackCompletions,
    Map<String, int>? artistImpressions,
    Map<String, int>? artistClicks,
    int? totalPlays,
    int? totalLikes,
    int? totalSkips,
    DateTime? lastUpdated,
  }) {
    return UserMusicProfile(
      artistScores: artistScores ?? this.artistScores,
      genreScores: genreScores ?? this.genreScores,
      languageScores: languageScores ?? this.languageScores,
      playlistThemeScores: playlistThemeScores ?? this.playlistThemeScores,
      trackScores: trackScores ?? this.trackScores,
      trackPlays: trackPlays ?? this.trackPlays,
      trackCompletions: trackCompletions ?? this.trackCompletions,
      artistImpressions: artistImpressions ?? this.artistImpressions,
      artistClicks: artistClicks ?? this.artistClicks,
      totalPlays: totalPlays ?? this.totalPlays,
      totalLikes: totalLikes ?? this.totalLikes,
      totalSkips: totalSkips ?? this.totalSkips,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
