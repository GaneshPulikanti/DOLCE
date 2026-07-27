class YoutubePlaylist {
  final String id;
  final String title;
  final String? description;
  final String? artworkUrl;
  final int? trackCount;

  const YoutubePlaylist({
    required this.id,
    required this.title,
    this.description,
    this.artworkUrl,
    this.trackCount,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'artworkUrl': artworkUrl,
      'trackCount': trackCount,
    };
  }

  factory YoutubePlaylist.fromJson(Map<String, dynamic> json) {
    return YoutubePlaylist(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      artworkUrl: json['artworkUrl'] as String?,
      trackCount: json['trackCount'] as int?,
    );
  }
}
