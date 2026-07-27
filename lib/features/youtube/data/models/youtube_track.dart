class YoutubeTrack {
  final String id;
  final String title;
  final String artistName;
  final String? artistId;
  final String? albumName;
  final String? albumId;
  final String? artworkUrl;
  final Duration? duration;
  final bool isMusicVideo;

  // v4.1 Metadata Cluster Personalization properties
  final String? language;
  final String? mood;
  final int? releaseYear;
  final double? energyScore;
  final double? popularityScore;
  final bool isOfficialMusic;
  final bool isTopicChannel;
  final String? recommendationReason;
  final DateTime? releaseDate;

  const YoutubeTrack({
    required this.id,
    required this.title,
    required this.artistName,
    this.artistId,
    this.albumName,
    this.albumId,
    this.artworkUrl,
    this.duration,
    this.isMusicVideo = false,
    this.language,
    this.mood,
    this.releaseYear,
    this.energyScore,
    this.popularityScore,
    this.isOfficialMusic = true,
    this.isTopicChannel = false,
    this.recommendationReason,
    this.releaseDate,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artistName': artistName,
        'artistId': artistId,
        'albumName': albumName,
        'albumId': albumId,
        'artworkUrl': artworkUrl,
        'durationMs': duration?.inMilliseconds,
        'isMusicVideo': isMusicVideo,
        'language': language,
        'mood': mood,
        'releaseYear': releaseYear,
        'energyScore': energyScore,
        'popularityScore': popularityScore,
        'isOfficialMusic': isOfficialMusic,
        'isTopicChannel': isTopicChannel,
        'recommendationReason': recommendationReason,
        'releaseDate': releaseDate?.toIso8601String(),
      };

  factory YoutubeTrack.fromJson(Map<String, dynamic> json) {
    return YoutubeTrack(
      id: json['id'] as String,
      title: json['title'] as String,
      artistName: json['artistName'] as String,
      artistId: json['artistId'] as String?,
      albumName: json['albumName'] as String?,
      albumId: json['albumId'] as String?,
      artworkUrl: json['artworkUrl'] as String?,
      duration: json['durationMs'] != null
          ? Duration(milliseconds: json['durationMs'] as int)
          : null,
      isMusicVideo: json['isMusicVideo'] as bool? ?? false,
      language: json['language'] as String?,
      mood: json['mood'] as String?,
      releaseYear: json['releaseYear'] as int?,
      energyScore: (json['energyScore'] as num?)?.toDouble(),
      popularityScore: (json['popularityScore'] as num?)?.toDouble(),
      isOfficialMusic: json['isOfficialMusic'] as bool? ?? true,
      isTopicChannel: json['isTopicChannel'] as bool? ?? false,
      recommendationReason: json['recommendationReason'] as String?,
      releaseDate: json['releaseDate'] != null ? DateTime.parse(json['releaseDate'] as String) : null,
    );
  }

  YoutubeTrack copyWith({
    String? id,
    String? title,
    String? artistName,
    String? artistId,
    String? albumName,
    String? albumId,
    String? artworkUrl,
    Duration? duration,
    bool? isMusicVideo,
    String? language,
    String? mood,
    int? releaseYear,
    double? energyScore,
    double? popularityScore,
    bool? isOfficialMusic,
    bool? isTopicChannel,
    String? recommendationReason,
    DateTime? releaseDate,
  }) {
    return YoutubeTrack(
      id: id ?? this.id,
      title: title ?? this.title,
      artistName: artistName ?? this.artistName,
      artistId: artistId ?? this.artistId,
      albumName: albumName ?? this.albumName,
      albumId: albumId ?? this.albumId,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      duration: duration ?? this.duration,
      isMusicVideo: isMusicVideo ?? this.isMusicVideo,
      language: language ?? this.language,
      mood: mood ?? this.mood,
      releaseYear: releaseYear ?? this.releaseYear,
      energyScore: energyScore ?? this.energyScore,
      popularityScore: popularityScore ?? this.popularityScore,
      isOfficialMusic: isOfficialMusic ?? this.isOfficialMusic,
      isTopicChannel: isTopicChannel ?? this.isTopicChannel,
      recommendationReason: recommendationReason ?? this.recommendationReason,
      releaseDate: releaseDate ?? this.releaseDate,
    );
  }
}
