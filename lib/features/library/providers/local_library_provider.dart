import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import '../../youtube/data/models/youtube_track.dart';
import '../../player/data/services/youtube_stream_resolver.dart';

class LocalPlaylist {
  final String id;
  final String name;
  final List<YoutubeTrack> tracks;
  final DateTime createdAt;

  LocalPlaylist({
    required this.id,
    required this.name,
    required this.tracks,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'tracks': tracks.map((t) => t.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory LocalPlaylist.fromJson(Map<String, dynamic> json) {
    return LocalPlaylist(
      id: json['id'] as String,
      name: json['name'] as String,
      tracks: (json['tracks'] as List<dynamic>?)
              ?.map((t) => YoutubeTrack.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }
}

class LocalLibraryState {
  final List<YoutubeTrack> favorites;
  final Map<String, LocalPlaylist> playlists;
  final List<YoutubeTrack> downloads;

  const LocalLibraryState({
    this.favorites = const [],
    this.playlists = const {},
    this.downloads = const [],
  });

  LocalLibraryState copyWith({
    List<YoutubeTrack>? favorites,
    Map<String, LocalPlaylist>? playlists,
    List<YoutubeTrack>? downloads,
  }) {
    return LocalLibraryState(
      favorites: favorites ?? this.favorites,
      playlists: playlists ?? this.playlists,
      downloads: downloads ?? this.downloads,
    );
  }
}

class LocalLibraryNotifier extends StateNotifier<LocalLibraryState> {
  LocalLibraryNotifier() : super(const LocalLibraryState()) {
    _loadFromHive();
  }

  void _loadFromHive() {
    final box = Hive.box('user_profile');
    
    // Load favorites
    final favsJson = box.get('local_favorites') as String?;
    var favorites = <YoutubeTrack>[];
    if (favsJson != null) {
      try {
        final decoded = json.decode(favsJson) as List<dynamic>;
        favorites = decoded
            .map((e) => YoutubeTrack.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        print('Error loading local favorites: $e');
      }
    }

    // Load playlists
    final playlistsJson = box.get('local_playlists') as String?;
    var playlists = <String, LocalPlaylist>{};
    if (playlistsJson != null) {
      try {
        final decoded = json.decode(playlistsJson) as Map<String, dynamic>;
        playlists = decoded.map(
          (k, v) => MapEntry(k, LocalPlaylist.fromJson(v as Map<String, dynamic>)),
        );
      } catch (e) {
        print('Error loading local playlists: $e');
      }
    }

    // Load downloads
    final downloadsJson = box.get('local_downloads') as String?;
    var downloads = <YoutubeTrack>[];
    if (downloadsJson != null) {
      try {
        final decoded = json.decode(downloadsJson) as List<dynamic>;
        downloads = decoded
            .map((e) => YoutubeTrack.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        print('Error loading local downloads: $e');
      }
    }

    state = LocalLibraryState(
      favorites: favorites,
      playlists: playlists,
      downloads: downloads,
    );
  }

  Future<void> _saveFavorites(List<YoutubeTrack> favorites) async {
    final box = Hive.box('user_profile');
    final encoded = json.encode(favorites.map((t) => t.toJson()).toList());
    await box.put('local_favorites', encoded);
  }

  Future<void> _savePlaylists(Map<String, LocalPlaylist> playlists) async {
    final box = Hive.box('user_profile');
    final encoded = json.encode(playlists.map((k, v) => MapEntry(k, v.toJson())));
    await box.put('local_playlists', encoded);
  }

  Future<void> _saveDownloads(List<YoutubeTrack> downloads) async {
    final box = Hive.box('user_profile');
    final encoded = json.encode(downloads.map((t) => t.toJson()).toList());
    await box.put('local_downloads', encoded);
  }

  // Downloads
  Future<void> addDownload(YoutubeTrack track) async {
    if (state.downloads.any((t) => t.id == track.id)) return;
    
    // Download actual bytes and save in Hive
    try {
      final resolver = YoutubeStreamResolver();
      final streamUrl = await resolver.resolveStreamUrl(track.id);
      if (streamUrl != null) {
        print('⬇️ Caching audio stream bytes for offline: ${track.title}');
        final response = await http.get(Uri.parse(streamUrl));
        if (response.statusCode == 200) {
          final box = Hive.box('offline_audio_data');
          await box.put(track.id, response.bodyBytes);
          print('💾 Successfully cached offline audio bytes for: ${track.title} (${response.bodyBytes.length} bytes)');
        } else {
          print('⚠️ HTTP download status ${response.statusCode} for ${track.title}');
        }
      } else {
        print('⚠️ Could not resolve stream URL for offline cache: ${track.title}');
      }
    } catch (e) {
      print('⚠️ Failed to download audio bytes for offline: $e');
    }

    final updated = [...state.downloads, track];
    state = state.copyWith(downloads: updated);
    await _saveDownloads(updated);
  }

  Future<void> removeDownload(String trackId) async {
    final updated = state.downloads.where((t) => t.id != trackId).toList();
    state = state.copyWith(downloads: updated);
    await _saveDownloads(updated);

    try {
      final box = Hive.box('offline_audio_data');
      await box.delete(trackId);
      print('🗑️ Deleted offline audio cache for $trackId');
    } catch (e) {
      print('⚠️ Failed to delete offline audio cache: $e');
    }
  }

  bool isDownloaded(String trackId) {
    return state.downloads.any((t) => t.id == trackId);
  }

  // Favourites
  void toggleFavorite(YoutubeTrack track) {
    final isFav = state.favorites.any((t) => t.id == track.id);
    List<YoutubeTrack> updated;
    if (isFav) {
      updated = state.favorites.where((t) => t.id != track.id).toList();
    } else {
      updated = [...state.favorites, track];
    }
    state = state.copyWith(favorites: updated);
    _saveFavorites(updated);
  }

  bool isFavorite(String trackId) {
    return state.favorites.any((t) => t.id == trackId);
  }

  // Playlists
  String createPlaylist(String name) {
    final id = 'local_playlist_${DateTime.now().millisecondsSinceEpoch}';
    final newPlaylist = LocalPlaylist(
      id: id,
      name: name,
      tracks: [],
      createdAt: DateTime.now(),
    );
    final updated = Map<String, LocalPlaylist>.from(state.playlists)
      ..[id] = newPlaylist;
    state = state.copyWith(playlists: updated);
    _savePlaylists(updated);
    return id;
  }

  void deletePlaylist(String playlistId) {
    final updated = Map<String, LocalPlaylist>.from(state.playlists)
      ..remove(playlistId);
    state = state.copyWith(playlists: updated);
    _savePlaylists(updated);
  }

  void addTrackToPlaylist(String playlistId, YoutubeTrack track) {
    final playlist = state.playlists[playlistId];
    if (playlist == null) return;
    
    // Check if track already in playlist
    if (playlist.tracks.any((t) => t.id == track.id)) return;

    final updatedTracks = [...playlist.tracks, track];
    final updatedPlaylist = LocalPlaylist(
      id: playlist.id,
      name: playlist.name,
      tracks: updatedTracks,
      createdAt: playlist.createdAt,
    );

    final updatedPlaylists = Map<String, LocalPlaylist>.from(state.playlists)
      ..[playlistId] = updatedPlaylist;
    
    state = state.copyWith(playlists: updatedPlaylists);
    _savePlaylists(updatedPlaylists);
  }

  void removeTrackFromPlaylist(String playlistId, String trackId) {
    final playlist = state.playlists[playlistId];
    if (playlist == null) return;

    final updatedTracks = playlist.tracks.where((t) => t.id != trackId).toList();
    final updatedPlaylist = LocalPlaylist(
      id: playlist.id,
      name: playlist.name,
      tracks: updatedTracks,
      createdAt: playlist.createdAt,
    );

    final updatedPlaylists = Map<String, LocalPlaylist>.from(state.playlists)
      ..[playlistId] = updatedPlaylist;
    
    state = state.copyWith(playlists: updatedPlaylists);
    _savePlaylists(updatedPlaylists);
  }
}

final localLibraryProvider =
    StateNotifierProvider<LocalLibraryNotifier, LocalLibraryState>((ref) {
  return LocalLibraryNotifier();
});
