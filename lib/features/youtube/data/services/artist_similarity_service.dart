import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/providers/auth_provider.dart';

class ArtistSimilarityService {
  final Map<String, Map<String, double>> _graph = {};

  final Map<String, List<String>> _staticRelations = {
    'Devi Sri Prasad (DSP)': ['Thaman S', 'M.M. Keeravani', 'Harris Jayaraj', 'Anirudh Ravichander', 'A.R. Rahman', 'Mani Sharma'],
    'Anirudh Ravichander': ['Devi Sri Prasad (DSP)', 'Harris Jayaraj', 'Yuvan Shankar Raja', 'G.V. Prakash Kumar', 'Thaman S', 'A.R. Rahman'],
    'Sid Sriram': ['Anirudh Ravichander', 'A.R. Rahman', 'Karthik', 'Hariharan', 'Shreya Ghoshal'],
    'A.R. Rahman': ['Harris Jayaraj', 'Yuvan Shankar Raja', 'Devi Sri Prasad (DSP)', 'M.M. Keeravani', 'Ilaiyaraaja', 'S.P. Balasubrahmanyam'],
    'Harris Jayaraj': ['Yuvan Shankar Raja', 'Anirudh Ravichander', 'A.R. Rahman', 'G.V. Prakash Kumar', 'Karthik'],
    'Yuvan Shankar Raja': ['Anirudh Ravichander', 'Harris Jayaraj', 'G.V. Prakash Kumar', 'Ilaiyaraaja'],
    'S.P. Balasubrahmanyam': ['K.S. Chithra', 'Ilaiyaraaja', 'P. Susheela', 'Yesudas', 'Hariharan', 'S. Janaki'],
    'K.S. Chithra': ['S.P. Balasubrahmanyam', 'S. Janaki', 'P. Susheela', 'Yesudas', 'Shreya Ghoshal'],
    'Arijit Singh': ['Jubin Nautiyal', 'Atif Aslam', 'Armaan Malik', 'Pritam', 'Shreya Ghoshal', 'Mithoon'],
    'Shreya Ghoshal': ['Arijit Singh', 'Sunidhi Chauhan', 'Alka Yagnik', 'K.S. Chithra', 'Sonu Nigam'],
    'Pritam': ['Arijit Singh', 'Vishal-Shekhar', 'Amit Trivedi', 'Sachin-Jigar', 'Badshah', 'A.R. Rahman'],
    'Badshah': ['Raftaar', 'Yo Yo Honey Singh', 'Divine', 'Diljit Dosanjh', 'Guru Randhawa'],
    'Diljit Dosanjh': ['Sidhu Moose Wala', 'AP Dhillon', 'Guru Randhawa', 'Badshah', 'Karan Aujla'],
    'Sidhu Moose Wala': ['Karan Aujla', 'Amrit Maan', 'Diljit Dosanjh', 'AP Dhillon', 'Shubh'],
    'The Weeknd': ['Dua Lipa', 'Post Malone', 'Drake', 'Travis Scott', 'Justin Bieber', 'Taylor Swift'],
    'Ed Sheeran': ['Taylor Swift', 'Shawn Mendes', 'Coldplay', 'Justin Bieber', 'One Direction', 'Adele'],
    'Taylor Swift': ['Ed Sheeran', 'Selena Gomez', 'Olivia Rodrigo', 'Billie Eilish', 'Lana Del Rey', 'Sabrina Carpenter'],
    'BTS': ['BLACKPINK', 'EXO', 'TXT', 'NewJeans', 'Stray Kids', 'Jungkook'],
    'Billie Eilish': ['Olivia Rodrigo', 'Lana Del Rey', 'Taylor Swift', 'Finneas', 'Lorde'],
    'Dua Lipa': ['The Weeknd', 'Miley Cyrus', 'Ariana Grande', 'Rita Ora', 'Katy Perry'],
    'Drake': ['Travis Scott', 'Kendrick Lamar', 'Future', 'Kanye West', 'Lil Baby', 'J. Cole', 'The Weeknd'],
    'Justin Bieber': ['Shawn Mendes', 'Justin Timberlake', 'Selena Gomez', 'Zayn', 'Charlie Puth'],
    'Alan Walker': ['Martin Garrix', 'Marshmello', 'The Chainsmokers', 'David Guetta', 'Avicii', 'Kygo'],
    'Coldplay': ['OneRepublic', 'Imagine Dragons', 'Maroon 5', 'U2', 'Ed Sheeran'],
  };

  ArtistSimilarityService() {
    _loadFromHive();
  }

  void _loadFromHive() {
    // Load static graph as initial base
    for (final entry in _staticRelations.entries) {
      final Map<String, double> map = {};
      for (final rel in entry.value) {
        map[rel] = 0.50; // Initial moderate similarity for static list
      }
      _graph[entry.key] = map;
    }

    try {
      final box = Hive.box('user_profile');
      final raw = box.get('similarity_graph') as String?;
      if (raw != null) {
        final Map<String, dynamic> decoded = json.decode(raw);
        decoded.forEach((key, val) {
          final Map<String, double> map = {};
          if (val is Map) {
            val.forEach((k, v) {
              map[k] = (v as num).toDouble();
            });
          }
          if (_graph.containsKey(key)) {
            _graph[key]!.addAll(map);
          } else {
            _graph[key] = map;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _saveToHive() async {
    try {
      final box = Hive.box('user_profile');
      await box.put('similarity_graph', json.encode(_graph));
    } catch (_) {}
  }

  List<String> getSimilarArtists(String artist) {
    final artistLower = artist.toLowerCase().trim();
    String? matchingKey;
    for (final key in _graph.keys) {
      if (key.toLowerCase().trim() == artistLower) {
        matchingKey = key;
        break;
      }
    }
    
    if (matchingKey == null) return [];
    
    final sortedRelations = _graph[matchingKey]!.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sortedRelations.map((e) => e.key).toList();
  }

  double similarityScore(String artistA, String artistB) {
    final a = artistA.toLowerCase().trim();
    final b = artistB.toLowerCase().trim();
    if (a == b) return 1.0;
    
    String? matchingKey;
    for (final key in _graph.keys) {
      if (key.toLowerCase().trim() == a) {
        matchingKey = key;
        break;
      }
    }
    
    if (matchingKey == null) return 0.0;
    
    final map = _graph[matchingKey]!;
    for (final entry in map.entries) {
      if (entry.key.toLowerCase().trim() == b) {
        return entry.value;
      }
    }
    return 0.0;
  }

  Future<void> learnRelationship(String artistA, String artistB, {double increment = 0.05}) async {
    final a = artistA.trim();
    final b = artistB.trim();
    if (a.isEmpty || b.isEmpty || a.toLowerCase() == b.toLowerCase()) return;

    // We do bidirectional learning
    _incrementScore(a, b, increment);
    _incrementScore(b, a, increment);
    
    await _saveToHive();
  }

  void _incrementScore(String from, String to, double increment) {
    if (!_graph.containsKey(from)) {
      _graph[from] = {};
    }
    final current = _graph[from]![to] ?? 0.0;
    _graph[from]![to] = (current + increment).clamp(0.0, 1.0);
  }

  Future<void> learnFromLibrary(SyncedLibraryState library) async {
    // 1. Co-occurrence in user playlists
    for (final entry in library.playlistTracks.entries) {
      final tracks = entry.value;
      final artists = tracks.map((t) => t.artistName).toSet().toList();
      for (int i = 0; i < artists.length; i++) {
        for (int j = i + 1; j < artists.length; j++) {
          await learnRelationship(artists[i], artists[j], increment: 0.10);
        }
      }
    }

    // 2. Co-occurrence in liked songs
    final likedArtists = library.likedSongs.map((s) => s.artistName).toSet().toList();
    for (int i = 0; i < likedArtists.length; i++) {
      for (int j = i + 1; j < likedArtists.length; j++) {
        await learnRelationship(likedArtists[i], likedArtists[j], increment: 0.02);
      }
    }
  }

  Map<String, Map<String, double>> getFullGraph() => Map.unmodifiable(_graph);
}

final artistSimilarityProvider = Provider<ArtistSimilarityService>((ref) {
  return ArtistSimilarityService();
});
