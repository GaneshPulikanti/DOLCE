import '../../../youtube/data/models/youtube_track.dart';
import '../../../youtube/data/repositories/ytmusic_repository.dart';
import '../../../auth/data/models/user_preference_profile.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../youtube/data/services/session_intelligence_service.dart';
import '../../../youtube/data/services/taste_cluster_service.dart';

class AutoplayQueueGenerator {
  static List<YoutubeTrack> _filterQueueTracks(List<YoutubeTrack> tracks) {
    final blacklist = [
      'shorts', '#shorts', 'tiktok', 'fashion', 'outfit', 'haul',
      'vlog', 'trailer', 'teaser', 'clip', 'sound effect', 'preview',
      'unboxing', 'review', 'makeup', 'grwm', 'lookbook', 'style',
      'reels', 'reel', 'reaction', 'gaming', 'tutorial'
    ];
    return tracks.where((track) {
      if (track.id.trim().isEmpty) return false;
      final title = track.title.toLowerCase();
      final artist = track.artistName.toLowerCase();
      if (blacklist.any((word) => title.contains(word) || artist.contains(word))) {
        return false;
      }
      if (track.duration != null && track.duration!.inSeconds < 60) {
        return false;
      }
      if (track.isOfficialMusic == false) {
        return false;
      }
      return true;
    }).toList();
  }

  static Future<List<YoutubeTrack>> generateQueue({
    required YoutubeTrack currentTrack,
    required YTMusicRepository repo,
    required UserPreferenceProfile? preferences,
    required List<YoutubeTrack> recentPlayed,
    required SyncedLibraryState library,
    required UserMusicProfile musicProfile,
    required SessionProfile sessionProfile,
    required List<ListeningCluster> tasteClusters,
    required double Function(YoutubeTrack, {bool isDiscovery}) scoreTrack,
    bool recoveryMode = false,
  }) async {
    print('🎵 [QueueGenerator] Starting queue generation (v4.1) for "${currentTrack.title}" by "${currentTrack.artistName}" (recoveryMode=$recoveryMode)');

    // 1. History Avoidance: avoid recommending the last 20 played tracks
    final recentIds = recentPlayed.take(20).map((t) => t.id).toSet();
    final globalSeen = <String>{currentTrack.id, ...recentIds};

    // 2. Fetch Candidates for each pool
    final sessionCandidates = <String, YoutubeTrack>{};
    final clusterCandidates = <String, YoutubeTrack>{};
    final favoritesCandidates = <String, YoutubeTrack>{};
    final followedCandidates = <String, YoutubeTrack>{};
    final discoveryCandidates = <String, YoutubeTrack>{};

    // Pool A: Session Context
    final sessionArtists = sessionProfile.dominantArtists;
    for (final artist in sessionArtists.take(2)) {
      try {
        final songs = await repo.searchSongs(artist);
        for (final t in _filterQueueTracks(songs)) {
          sessionCandidates[t.id] = t;
        }
      } catch (_) {}
    }
    if (sessionProfile.dominantLanguage != 'Unknown' && sessionProfile.dominantGenre != 'Unknown') {
      try {
        final songs = await repo.searchSongs('${sessionProfile.dominantLanguage} ${sessionProfile.dominantGenre} hits');
        for (final t in _filterQueueTracks(songs)) {
          sessionCandidates[t.id] = t;
        }
      } catch (_) {}
    }

    // Pool B: Taste Clusters
    for (final cluster in tasteClusters.take(2)) {
      for (final artist in cluster.artists.take(3)) {
        try {
          final songs = await repo.searchSongs(artist);
          for (final t in _filterQueueTracks(songs)) {
            clusterCandidates[t.id] = t;
          }
        } catch (_) {}
      }
    }

    // Pool C: Favorites
    for (final song in library.likedSongs) {
      favoritesCandidates[song.id] = song;
    }
    // Find user's top played artists based on play count map
    final trackPlays = musicProfile.trackPlays;
    final sortedTrackIds = trackPlays.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final topPlayedArtists = <String>{};
    for (final entry in sortedTrackIds) {
      final playedTrackId = entry.key;
      YoutubeTrack? matchedTrack;
      if (currentTrack.id == playedTrackId) {
        matchedTrack = currentTrack;
      } else {
        try {
          matchedTrack = recentPlayed.firstWhere((t) => t.id == playedTrackId);
        } catch (_) {}
        if (matchedTrack == null) {
          try {
            matchedTrack = library.likedSongs.firstWhere((t) => t.id == playedTrackId);
          } catch (_) {}
        }
      }
      if (matchedTrack != null) {
        topPlayedArtists.add(matchedTrack.artistName);
      }
      if (topPlayedArtists.length >= 4) break;
    }

    final searchArtists = topPlayedArtists.isNotEmpty
        ? topPlayedArtists.toList()
        : (preferences?.artists ?? ['Sid Sriram', 'A.R. Rahman']);

    for (final artist in searchArtists.take(3)) {
      try {
        final songs = await repo.searchSongs(artist);
        for (final t in _filterQueueTracks(songs)) {
          favoritesCandidates[t.id] = t;
        }
      } catch (_) {}
    }

    // Pool D: Followed Artists (Use other top played or onboarding artists)
    final secondaryArtists = searchArtists.skip(3).toList();
    if (secondaryArtists.isEmpty) {
      secondaryArtists.addAll(library.musicArtists.map((a) => a.name));
    }
    if (secondaryArtists.isEmpty) {
      secondaryArtists.addAll(preferences?.artists ?? []);
    }
    for (final artist in secondaryArtists.take(4)) {
      try {
        final songs = await repo.searchSongs(artist);
        for (final t in _filterQueueTracks(songs)) {
          followedCandidates[t.id] = t;
        }
      } catch (_) {}
    }

    // Pool E: Discovery
    try {
      final trending = await repo.searchSongs('trending global hits');
      for (final t in _filterQueueTracks(trending)) {
        discoveryCandidates[t.id] = t;
      }
    } catch (_) {}
    try {
      final releases = await repo.searchSongs('new releases music');
      for (final t in _filterQueueTracks(releases)) {
        discoveryCandidates[t.id] = t;
      }
    } catch (_) {}

    // Score and filter duplicates
    List<YoutubeTrack> scoreAndSort(Map<String, YoutubeTrack> candidates, {bool isDiscovery = false}) {
      final list = candidates.values.where((t) => !globalSeen.contains(t.id)).toList();
      final scored = list.map((t) => MapEntry(t, scoreTrack(t, isDiscovery: isDiscovery))).toList();
      scored.sort((a, b) => b.value.compareTo(a.value));
      return scored.map((e) => e.key).toList();
    }

    final sessionPool = scoreAndSort(sessionCandidates);
    final clusterPool = scoreAndSort(clusterCandidates);
    final favoritesPool = scoreAndSort(favoritesCandidates);
    final followedPool = scoreAndSort(followedCandidates);
    final discoveryPool = scoreAndSort(discoveryCandidates, isDiscovery: true);

    // 3. Define target counts based on Mode (v4.1 queue composition)
    final int totalSize = 40;
    int sessionTarget;
    int clusterTarget;
    int favoritesTarget;
    int followedTarget;
    int discoveryTarget;

    if (recoveryMode) {
      // Recovery Mode: Shift towards historical favorites/followed, de-emphasize session
      sessionTarget = (totalSize * 0.10).toInt();     // 4
      clusterTarget = (totalSize * 0.20).toInt();     // 8
      favoritesTarget = (totalSize * 0.45).toInt();   // 18
      followedTarget = (totalSize * 0.20).toInt();    // 8
      discoveryTarget = (totalSize * 0.05).toInt();   // 2
    } else {
      // Normal Mode
      sessionTarget = (totalSize * 0.40).toInt();     // 16
      clusterTarget = (totalSize * 0.30).toInt();     // 12
      favoritesTarget = (totalSize * 0.15).toInt();   // 6
      followedTarget = (totalSize * 0.10).toInt();    // 4
      discoveryTarget = (totalSize * 0.05).toInt();   // 2
    }

    final selectedSession = <YoutubeTrack>[];
    final selectedCluster = <YoutubeTrack>[];
    final selectedFavorites = <YoutubeTrack>[];
    final selectedFollowed = <YoutubeTrack>[];
    final selectedDiscovery = <YoutubeTrack>[];

    final queueSeenIds = <String>{};

    void selectFromPool(List<YoutubeTrack> pool, List<YoutubeTrack> output, int target) {
      for (final track in pool) {
        if (output.length >= target) break;
        if (queueSeenIds.add(track.id)) {
          output.add(track);
        }
      }
    }

    selectFromPool(sessionPool, selectedSession, sessionTarget);
    selectFromPool(clusterPool, selectedCluster, clusterTarget);
    selectFromPool(favoritesPool, selectedFavorites, favoritesTarget);
    selectFromPool(followedPool, selectedFollowed, followedTarget);
    selectFromPool(discoveryPool, selectedDiscovery, discoveryTarget);

    // Backfill if we don't have enough selected items
    final backfilled = <YoutubeTrack>[];
    final allRemaining = <YoutubeTrack>[
      ...sessionPool,
      ...clusterPool,
      ...favoritesPool,
      ...followedPool,
      ...discoveryPool,
    ];
    allRemaining.sort((a, b) => scoreTrack(b).compareTo(scoreTrack(a)));

    for (final track in allRemaining) {
      final totalSelected = selectedSession.length +
                            selectedCluster.length +
                            selectedFavorites.length +
                            selectedFollowed.length +
                            selectedDiscovery.length +
                            backfilled.length;
      if (totalSelected >= totalSize) break;
      if (queueSeenIds.add(track.id)) {
        backfilled.add(track);
      }
    }

    // 4. Interleave selected streams to ensure balanced listening experience
    final streams = [
      selectedSession,
      selectedCluster,
      selectedFavorites,
      selectedFollowed,
      selectedDiscovery,
      backfilled,
    ];
    final interleaved = <YoutubeTrack>[];
    bool addedAny = true;
    final indices = List<int>.filled(streams.length, 0);

    while (addedAny) {
      addedAny = false;
      for (int i = 0; i < streams.length; i++) {
        final stream = streams[i];
        final idx = indices[i];
        if (idx < stream.length) {
          interleaved.add(stream[idx]);
          indices[i] = idx + 1;
          addedAny = true;
        }
      }
    }

    // 5. Sequence interleaved tracks to enforce max 2 consecutive tracks limit per artist
    final sequenced = <YoutubeTrack>[];
    final pending = List<YoutubeTrack>.from(interleaved);

    while (pending.isNotEmpty) {
      String? lastArtist;
      String? secondLastArtist;
      if (sequenced.length >= 1) {
        lastArtist = sequenced[sequenced.length - 1].artistName.toLowerCase().trim();
      }
      if (sequenced.length >= 2) {
        secondLastArtist = sequenced[sequenced.length - 2].artistName.toLowerCase().trim();
      }

      bool found = false;
      for (int i = 0; i < pending.length; i++) {
        final candidate = pending[i];
        final candArtist = candidate.artistName.toLowerCase().trim();

        if (lastArtist == candArtist && secondLastArtist == candArtist) {
          continue; // Skip to prevent consecutive violation
        }

        sequenced.add(candidate);
        pending.removeAt(i);
        found = true;
        break;
      }

      if (!found) {
        // Fallback: append next track if no non-violating candidate is left
        sequenced.add(pending.removeAt(0));
      }
    }

    print('🟢 [QueueGenerator] Generated smart queue of ${sequenced.length} tracks (history size=${recentIds.length}).');
    return sequenced;
  }
}
