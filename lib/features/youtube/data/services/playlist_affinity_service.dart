import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PlaylistAffinityService {
  final Map<String, int> _plays = {};
  final Map<String, int> _opens = {};
  final Map<String, int> _likes = {};

  PlaylistAffinityService() {
    _loadFromHive();
  }

  void _loadFromHive() {
    try {
      final box = Hive.box('user_profile');
      final rawPlays = box.get('playlist_plays_count') as String?;
      if (rawPlays != null) {
        final Map<String, dynamic> decoded = json.decode(rawPlays);
        decoded.forEach((k, v) => _plays[k] = v as int);
      }
      
      final rawOpens = box.get('playlist_opens_count') as String?;
      if (rawOpens != null) {
        final Map<String, dynamic> decoded = json.decode(rawOpens);
        decoded.forEach((k, v) => _opens[k] = v as int);
      }
      
      final rawLikes = box.get('playlist_likes_count') as String?;
      if (rawLikes != null) {
        final Map<String, dynamic> decoded = json.decode(rawLikes);
        decoded.forEach((k, v) => _likes[k] = v as int);
      }
    } catch (_) {}
  }

  Future<void> _saveToHive() async {
    try {
      final box = Hive.box('user_profile');
      await box.put('playlist_plays_count', json.encode(_plays));
      await box.put('playlist_opens_count', json.encode(_opens));
      await box.put('playlist_likes_count', json.encode(_likes));
    } catch (_) {}
  }

  double getPlaylistAffinityScore(String playlistId) {
    final playCount = _plays[playlistId] ?? 0;
    final openCount = _opens[playlistId] ?? 0;
    final likeCount = _likes[playlistId] ?? 0;
    
    // Play counts: +10 each, opens: +2 each, likes: +15
    return (playCount * 10.0) + (openCount * 2.0) + (likeCount * 15.0);
  }

  Future<void> recordPlay(String playlistId) async {
    _plays[playlistId] = (_plays[playlistId] ?? 0) + 1;
    await _saveToHive();
  }

  Future<void> recordOpen(String playlistId) async {
    _opens[playlistId] = (_opens[playlistId] ?? 0) + 1;
    await _saveToHive();
  }

  Future<void> recordLike(String playlistId, bool isLiked) async {
    _likes[playlistId] = isLiked ? 1 : 0;
    await _saveToHive();
  }

  Map<String, int> getPlays() => Map.unmodifiable(_plays);
  Map<String, int> getOpens() => Map.unmodifiable(_opens);
  Map<String, int> getLikes() => Map.unmodifiable(_likes);
}

final playlistAffinityProvider = Provider<PlaylistAffinityService>((ref) {
  return PlaylistAffinityService();
});
