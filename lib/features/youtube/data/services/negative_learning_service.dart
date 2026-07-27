import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NegativeLearningService {
  final Map<String, int> _artistSkips = {};
  final Map<String, DateTime> _suppressions = {};

  NegativeLearningService() {
    _loadFromHive();
  }

  void _loadFromHive() {
    try {
      final box = Hive.box('user_profile');
      final rawSkips = box.get('artist_skips_count') as String?;
      if (rawSkips != null) {
        final Map<String, dynamic> decoded = json.decode(rawSkips);
        decoded.forEach((k, v) => _artistSkips[k] = v as int);
      }
      
      final rawSupps = box.get('artist_suppression_until') as String?;
      if (rawSupps != null) {
        final Map<String, dynamic> decoded = json.decode(rawSupps);
        decoded.forEach((k, v) => _suppressions[k] = DateTime.parse(v as String));
      }
    } catch (_) {}
  }

  Future<void> _saveToHive() async {
    try {
      final box = Hive.box('user_profile');
      await box.put('artist_skips_count', json.encode(_artistSkips));
      await box.put('artist_suppression_until', json.encode(
        _suppressions.map((k, v) => MapEntry(k, v.toIso8601String()))
      ));
    } catch (_) {}
  }

  bool isSuppressed(String artist) {
    final artistLower = artist.toLowerCase().trim();
    String? matchingKey;
    for (final key in _suppressions.keys) {
      if (key.toLowerCase().trim() == artistLower) {
        matchingKey = key;
        break;
      }
    }
    
    if (matchingKey == null) return false;
    
    final until = _suppressions[matchingKey]!;
    if (DateTime.now().isAfter(until)) {
      // Suppression has expired! Clean up.
      _suppressions.remove(matchingKey);
      _artistSkips[matchingKey] = 0; // Reset skips on expiry recovery
      _saveToHive();
      return false;
    }
    return true;
  }

  double getSkipPenalty(String artist) {
    final artistLower = artist.toLowerCase().trim();
    int skips = 0;
    for (final entry in _artistSkips.entries) {
      if (entry.key.toLowerCase().trim() == artistLower) {
        skips = entry.value;
        break;
      }
    }
    
    if (skips >= 10) return -30.0;
    if (skips >= 5) return -15.0;
    if (skips >= 3) return -5.0;
    return 0.0;
  }

  Future<void> recordSkip(String artist) async {
    final artistLower = artist.trim();
    if (artistLower.isEmpty) return;

    // Find if there is an existing matching key to preserve exact casing
    String artistKey = artistLower;
    for (final key in _artistSkips.keys) {
      if (key.toLowerCase().trim() == artistLower.toLowerCase().trim()) {
        artistKey = key;
        break;
      }
    }

    final skips = (_artistSkips[artistKey] ?? 0) + 1;
    _artistSkips[artistKey] = skips;

    if (skips >= 10) {
      // Suppress for 14 days
      _suppressions[artistKey] = DateTime.now().add(const Duration(days: 14));
      print('🚫 [NegativeLearning] Suppression active for "$artistKey" until ${_suppressions[artistKey]}');
    }

    await _saveToHive();
  }

  Future<void> recordPlay(String artist) async {
    // A play helps to slowly decay skip count
    final artistLower = artist.toLowerCase().trim();
    String? artistKey;
    for (final key in _artistSkips.keys) {
      if (key.toLowerCase().trim() == artistLower) {
        artistKey = key;
        break;
      }
    }
    if (artistKey != null) {
      final skips = _artistSkips[artistKey] ?? 0;
      if (skips > 0) {
        _artistSkips[artistKey] = skips - 1;
        await _saveToHive();
      }
    }
  }

  Map<String, int> getSkipCounts() => Map.unmodifiable(_artistSkips);
  Map<String, DateTime> getSuppressions() => Map.unmodifiable(_suppressions);
}

final negativeLearningProvider = Provider<NegativeLearningService>((ref) {
  return NegativeLearningService();
});
