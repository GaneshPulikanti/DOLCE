import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DiscoveryService {
  int _shown = 0;
  int _played = 0;
  int _completed = 0;

  DiscoveryService() {
    _loadFromHive();
  }

  void _loadFromHive() {
    try {
      final box = Hive.box('user_profile');
      _shown = box.get('discovery_shown') as int? ?? 0;
      _played = box.get('discovery_played') as int? ?? 0;
      _completed = box.get('discovery_completed') as int? ?? 0;
    } catch (_) {}
  }

  Future<void> _saveToHive() async {
    try {
      final box = Hive.box('user_profile');
      await box.put('discovery_shown', _shown);
      await box.put('discovery_played', _played);
      await box.put('discovery_completed', _completed);
    } catch (_) {}
  }

  double getDiscoveryRatio() {
    if (_shown == 0) {
      return 0.20; // Default cold start: maximum permitted discovery for new profiles
    }
    
    final completionRate = _completed / _shown;
    if (completionRate > 0.60) {
      return 0.20; // Capped at 20% max discovery to avoid overloading playlists
    } else if (completionRate > 0.40) {
      return 0.15;
    } else if (completionRate > 0.20) {
      return 0.12;
    } else {
      return 0.10;
    }
  }

  double getCompletionRate() {
    if (_shown == 0) return 0.0;
    return _completed / _shown;
  }

  Future<void> recordShown() async {
    _shown++;
    await _saveToHive();
  }

  Future<void> recordPlayed() async {
    _played++;
    await _saveToHive();
  }

  Future<void> recordCompleted() async {
    _completed++;
    await _saveToHive();
  }

  int get shownCount => _shown;
  int get playedCount => _played;
  int get completedCount => _completed;
}

final discoveryProvider = Provider<DiscoveryService>((ref) {
  return DiscoveryService();
});
