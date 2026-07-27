/// Represents a YouTube channel that the user has subscribed to,
/// optionally identified as a music artist via topicDetails classification.
class YoutubeArtistChannel {
  final String channelId;
  final String name;
  final String? artworkUrl;

  /// Whether this channel was identified as a music artist via:
  /// - topicDetails.topicCategories containing a '/Music' Wikipedia URL
  /// - Channel title ending with ' - Topic'
  /// - Channel title containing 'VEVO' or 'Vevo'
  final bool isMusicArtist;

  /// Raw Wikipedia topic category URLs from channels.list topicDetails.
  /// e.g. ['https://en.wikipedia.org/wiki/Music', 'https://en.wikipedia.org/wiki/Hip_hop_music']
  final List<String> topicCategories;

  const YoutubeArtistChannel({
    required this.channelId,
    required this.name,
    this.artworkUrl,
    this.isMusicArtist = false,
    this.topicCategories = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'channelId': channelId,
      'name': name,
      'artworkUrl': artworkUrl,
      'isMusicArtist': isMusicArtist,
      'topicCategories': topicCategories,
    };
  }

  factory YoutubeArtistChannel.fromJson(Map<String, dynamic> json) {
    return YoutubeArtistChannel(
      channelId: json['channelId'] as String,
      name: json['name'] as String,
      artworkUrl: json['artworkUrl'] as String?,
      isMusicArtist: json['isMusicArtist'] as bool? ?? false,
      topicCategories: (json['topicCategories'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }

  YoutubeArtistChannel copyWith({
    String? channelId,
    String? name,
    String? artworkUrl,
    bool? isMusicArtist,
    List<String>? topicCategories,
  }) {
    return YoutubeArtistChannel(
      channelId: channelId ?? this.channelId,
      name: name ?? this.name,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      isMusicArtist: isMusicArtist ?? this.isMusicArtist,
      topicCategories: topicCategories ?? this.topicCategories,
    );
  }
}
