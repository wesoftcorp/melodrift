import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/theme_provider.dart';
import '../../domain/entities/song.dart';
import '../../core/utils/logger.dart';

final tasteProfilerServiceProvider = Provider<TasteProfilerService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return TasteProfilerService(prefs);
});

class TasteProfilerService {
  final SharedPreferences _prefs;
  final _log = AppLogger('TasteProfilerService');

  static const _artistScoresKey = 'taste_artist_scores';
  static const _songScoresKey = 'taste_song_scores';
  static const _recentSeedsKey = 'taste_recent_seeds';

  TasteProfilerService(this._prefs);

  /// Record a song listening event and update affinity weights
  Future<void> recordPlayEvent({
    required Song song,
    required Duration playedDuration,
    required Duration totalDuration,
    required bool isSkipped,
  }) async {
    try {
      final playedSec = playedDuration.inSeconds;
      final totalSec = totalDuration.inSeconds;

      int scoreDelta = 1;

      if (isSkipped && playedSec < 15) {
        // Skipped quickly -> negative signal
        scoreDelta = -2;
      } else if (totalSec > 0 && (playedSec >= (totalSec * 0.8) || playedSec >= 60)) {
        // Listened to completion (>80% or >1 minute) -> strong positive signal
        scoreDelta = 3;
      }

      await _updateScore(_artistScoresKey, song.artist, scoreDelta);
      await _updateScore(_songScoresKey, '${song.title}:::${song.artist}:::${song.id}', scoreDelta);
      await _recordRecentSeed(song);

      _log.info('Updated taste score for "${song.title}" by "${song.artist}" (delta: $scoreDelta)');
    } catch (e) {
      _log.error('Failed to record play event: $e');
    }
  }

  Future<void> _updateScore(String key, String itemKey, int delta) async {
    final raw = _prefs.getString(key);
    Map<String, dynamic> map = {};
    if (raw != null) {
      try {
        map = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {}
    }

    final currentScore = (map[itemKey] as int? ?? 0) + delta;
    if (currentScore <= 0) {
      map.remove(itemKey);
    } else {
      map[itemKey] = currentScore;
    }

    await _prefs.setString(key, jsonEncode(map));
  }

  Future<void> _recordRecentSeed(Song song) async {
    final raw = _prefs.getStringList(_recentSeedsKey) ?? [];
    final item = jsonEncode({
      'id': song.id,
      'title': song.title,
      'artist': song.artist,
      'artworkUrl': song.artworkUrl,
      'playedAt': DateTime.now().toIso8601String(),
    });

    final updated = [item, ...raw.where((x) {
      try {
        final m = jsonDecode(x) as Map<String, dynamic>;
        return m['id'] != song.id;
      } catch (_) {
        return false;
      }
    })].take(20).toList();

    await _prefs.setStringList(_recentSeedsKey, updated);
  }

  /// Get top artists ranked by user engagement
  List<String> getTopArtists({int limit = 5}) {
    final raw = _prefs.getString(_artistScoresKey);
    if (raw == null) return [];
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final entries = map.entries.toList()
        ..sort((a, b) => (b.value as int).compareTo(a.value as int));
      return entries.take(limit).map((e) => e.key).toList();
    } catch (_) {
      return [];
    }
  }

  /// Get recent listening seeds to feed the recommendation engine
  List<Map<String, dynamic>> getRecentSeeds({int limit = 5}) {
    final raw = _prefs.getStringList(_recentSeedsKey) ?? [];
    final List<Map<String, dynamic>> result = [];
    for (final str in raw.take(limit)) {
      try {
        result.add(jsonDecode(str) as Map<String, dynamic>);
      } catch (_) {}
    }
    return result;
  }
}
