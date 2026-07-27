import '../models/youtube_track.dart';
import '../../../auth/data/models/user_preference_profile.dart';
import '../../../auth/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ListeningCluster {
  final String name;
  final List<String> artists;
  final List<String> genres;
  final List<String> languages;

  ListeningCluster({
    required this.name,
    required this.artists,
    required this.genres,
    required this.languages,
  });

  String get displayName => name;
}

class TasteClusterService {
  List<ListeningCluster> generateTasteClusters({
    required UserPreferenceProfile? preferences,
    required SyncedLibraryState library,
    required UserMusicProfile musicProfile,
  }) {
    final clusters = <ListeningCluster>[];

    // Read languages from onboarding
    final languages = preferences?.languages ?? ['Telugu', 'Hindi', 'English'];
    
    // Group artists by language based on heuristics or listening profile
    final artistLanguages = <String, Map<String, int>>{};
    
    // Scan liked songs
    for (final song in library.likedSongs) {
      final artist = song.artistName;
      final lang = song.language ?? _estimateLanguage(song, languages);
      if (!artistLanguages.containsKey(artist)) {
        artistLanguages[artist] = {};
      }
      artistLanguages[artist]![lang] = (artistLanguages[artist]![lang] ?? 0) + 1;
    }
    
    // Scan playlist songs
    for (final entry in library.playlistTracks.entries) {
      for (final song in entry.value) {
        final artist = song.artistName;
        final lang = song.language ?? _estimateLanguage(song, languages);
        if (!artistLanguages.containsKey(artist)) {
          artistLanguages[artist] = {};
        }
        artistLanguages[artist]![lang] = (artistLanguages[artist]![lang] ?? 0) + 1;
      }
    }

    // Default artist language fallback map for onboarding artists
    final defaultArtistLanguages = {
      'Sid Sriram': 'Telugu',
      'Anirudh Ravichander': 'Tamil',
      'Arijit Singh': 'Hindi',
      'Taylor Swift': 'English',
      'The Weeknd': 'English',
      'BTS': 'Korean',
      'Ed Sheeran': 'English',
      'A.R. Rahman': 'Tamil',
      'Thaman S': 'Telugu',
      'Devi Sri Prasad (DSP)': 'Telugu',
    };

    // Determine primary language for each artist
    final artistPrimaryLanguage = <String, String>{};
    artistLanguages.forEach((artist, counts) {
      if (counts.isEmpty) return;
      final sorted = counts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      artistPrimaryLanguage[artist] = sorted.first.key;
    });

    // Feed onboarding artists
    if (preferences != null) {
      for (final artist in preferences.artists) {
        if (!artistPrimaryLanguage.containsKey(artist)) {
          artistPrimaryLanguage[artist] = defaultArtistLanguages[artist] ?? 'English';
        }
      }
    }

    // Genres mapping
    // We group by prominent language + genre clusters
    final genres = preferences?.genres ?? ['Melody', 'Romantic', 'EDM'];
    
    for (final lang in languages) {
      for (final genre in genres) {
        final clusterArtists = <String>[];
        artistPrimaryLanguage.forEach((artist, primaryLang) {
          if (primaryLang.toLowerCase() == lang.toLowerCase() ||
              (lang.toLowerCase() == 'telugu' && primaryLang.toLowerCase() == 'tamil') ||
              (lang.toLowerCase() == 'tamil' && primaryLang.toLowerCase() == 'telugu')) {
            clusterArtists.add(artist);
          }
        });

        // Only add cluster if we have matching artists
        if (clusterArtists.isNotEmpty) {
          clusters.add(ListeningCluster(
            name: '$lang $genre Cluster',
            artists: clusterArtists.toSet().toList(),
            genres: List<String>.from([genre, 'Romantic', 'Melody'].toSet()),
            languages: List<String>.from([lang, 'Tamil', 'Telugu'].toSet()),
          ));
        }
      }
    }

    // Cold start fallback
    if (clusters.isEmpty) {
      clusters.add(ListeningCluster(
        name: 'Telugu Melody Cluster',
        artists: ['Sid Sriram', 'Devi Sri Prasad (DSP)', 'Thaman S', 'Karthik'],
        genres: ['Melody', 'Romantic'],
        languages: ['Telugu', 'Tamil'],
      ));
      clusters.add(ListeningCluster(
        name: 'Hindi Romantic Cluster',
        artists: ['Arijit Singh', 'Pritam', 'Shreya Ghoshal'],
        genres: ['Romantic', 'Melody'],
        languages: ['Hindi'],
      ));
      clusters.add(ListeningCluster(
        name: 'English Pop Cluster',
        artists: ['The Weeknd', 'Taylor Swift', 'Ed Sheeran'],
        genres: ['EDM', 'Pop'],
        languages: ['English'],
      ));
    }

    return clusters;
  }

  String _estimateLanguage(YoutubeTrack song, List<String> preferredLanguages) {
    final titleLower = song.title.toLowerCase();
    // Quick heuristics
    if (titleLower.contains('love') || titleLower.contains('summer') || titleLower.contains('tears') || titleLower.contains('perfect') || titleLower.contains('shape')) {
      return 'English';
    }
    if (titleLower.contains('kadhaippoma') || titleLower.contains('samajavaragamana') || titleLower.contains('butta') || titleLower.contains('bomma') || titleLower.contains('adiga')) {
      return 'Telugu';
    }
    if (titleLower.contains('chaleya') || titleLower.contains('tum') || titleLower.contains('ho') || titleLower.contains('kabira')) {
      return 'Hindi';
    }
    if (titleLower.contains('hukum') || titleLower.contains('naa') || titleLower.contains('ready') || titleLower.contains('kuthu')) {
      return 'Tamil';
    }
    return preferredLanguages.isNotEmpty ? preferredLanguages.first : 'English';
  }
}

final tasteClusterProvider = Provider<TasteClusterService>((ref) {
  return TasteClusterService();
});
