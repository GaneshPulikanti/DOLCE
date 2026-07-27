import '../models/youtube_track.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SessionProfile {
  final List<String> dominantArtists;
  final String dominantLanguage;
  final String dominantMood;
  final String dominantGenre;
  final double energyScore;

  SessionProfile({
    required this.dominantArtists,
    required this.dominantLanguage,
    required this.dominantMood,
    required this.dominantGenre,
    required this.energyScore,
  });

  String get clusterName {
    if (dominantArtists.isEmpty) return 'No Session Context';
    final langPrefix = dominantLanguage != 'Unknown' ? '$dominantLanguage ' : '';
    final genreSuffix = dominantGenre != 'Unknown' ? dominantGenre : (dominantMood != 'Unknown' ? dominantMood : 'Music');
    return '$langPrefix$genreSuffix Session';
  }
}

class SessionIntelligenceService {
  final List<YoutubeTrack> _recentPlays = [];

  void recordPlay(YoutubeTrack track) {
    // Avoid duplicates in the recents list
    _recentPlays.removeWhere((t) => t.id == track.id);
    _recentPlays.insert(0, track);
    if (_recentPlays.length > 20) {
      _recentPlays.removeLast();
    }
  }

  List<YoutubeTrack> getRecentPlays() => List.unmodifiable(_recentPlays);

  SessionProfile getCurrentSessionProfile() {
    if (_recentPlays.isEmpty) {
      return SessionProfile(
        dominantArtists: [],
        dominantLanguage: 'Unknown',
        dominantMood: 'Unknown',
        dominantGenre: 'Unknown',
        energyScore: 0.5,
      );
    }

    // 1. Dominant artists
    final artistCounts = <String, int>{};
    for (final t in _recentPlays) {
      artistCounts[t.artistName] = (artistCounts[t.artistName] ?? 0) + 1;
    }
    final sortedArtists = artistCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final dominantArtists = sortedArtists.map((e) => e.key).take(3).toList();

    // 2. Dominant language
    final langCounts = <String, int>{};
    for (final t in _recentPlays) {
      final lang = t.language ?? 'Unknown';
      if (lang != 'Unknown') {
        langCounts[lang] = (langCounts[lang] ?? 0) + 1;
      }
    }
    String dominantLanguage = 'Unknown';
    if (langCounts.isNotEmpty) {
      dominantLanguage = (langCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value))).first.key;
    }

    // 3. Dominant mood
    final moodCounts = <String, int>{};
    for (final t in _recentPlays) {
      final mood = t.mood ?? 'Unknown';
      if (mood != 'Unknown') {
        moodCounts[mood] = (moodCounts[mood] ?? 0) + 1;
      }
    }
    String dominantMood = 'Unknown';
    if (moodCounts.isNotEmpty) {
      dominantMood = (moodCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value))).first.key;
    }

    // 4. Dominant genre (estimated or based on metadata tags/title keywords)
    final genreCounts = <String, int>{};
    for (final t in _recentPlays) {
      final titleLower = t.title.toLowerCase();
      String genre = 'Unknown';
      if (titleLower.contains('melody') || titleLower.contains('soft') || titleLower.contains('acoustic')) {
        genre = 'Melody';
      } else if (titleLower.contains('love') || titleLower.contains('romantic') || titleLower.contains('dil')) {
        genre = 'Romantic';
      } else if (titleLower.contains('edm') || titleLower.contains('dance') || titleLower.contains('electronic') || titleLower.contains('club')) {
        genre = 'EDM';
      } else if (titleLower.contains('hip hop') || titleLower.contains('rap') || titleLower.contains('trap')) {
        genre = 'Hip Hop';
      } else if (titleLower.contains('mass') || titleLower.contains('beat') || titleLower.contains('kuthu')) {
        genre = 'Mass';
      }
      if (genre != 'Unknown') {
        genreCounts[genre] = (genreCounts[genre] ?? 0) + 1;
      }
    }
    String dominantGenre = 'Unknown';
    if (genreCounts.isNotEmpty) {
      dominantGenre = (genreCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value))).first.key;
    }

    // 5. Energy score average
    double totalEnergy = 0.0;
    int energyCount = 0;
    for (final t in _recentPlays) {
      if (t.energyScore != null) {
        totalEnergy += t.energyScore!;
        energyCount++;
      }
    }
    final energyScore = energyCount > 0 ? (totalEnergy / energyCount) : 0.5;

    return SessionProfile(
      dominantArtists: dominantArtists,
      dominantLanguage: dominantLanguage,
      dominantMood: dominantMood,
      dominantGenre: dominantGenre,
      energyScore: energyScore,
    );
  }
}

final sessionIntelligenceProvider = Provider<SessionIntelligenceService>((ref) {
  return SessionIntelligenceService();
});
