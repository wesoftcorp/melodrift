import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../flavors.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/song.dart';

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AnalyticsService(prefs);
});

class AnalyticsService {
  final SharedPreferences _prefs;
  final _log = AppLogger('AnalyticsService');

  static const _totalPlaysKey = 'telemetry_total_plays';
  static const _totalMinutesKey = 'telemetry_total_minutes';

  AnalyticsService(this._prefs);

  /// Log song playback start
  Future<void> logSongPlayed(Song song) async {
    try {
      final currentPlays = _prefs.getInt(_totalPlaysKey) ?? 0;
      await _prefs.setInt(_totalPlaysKey, currentPlays + 1);

      if (F.isFull && !kIsWeb && Firebase.apps.isNotEmpty) {
        await FirebaseAnalytics.instance.logEvent(
          name: 'song_play_started',
          parameters: {
            'song_id': song.id,
            'song_title': song.title,
            'artist': song.artist,
            'source': song.source,
          },
        );
      }
      _log.info('Logged play event: ${song.title}');
    } catch (e) {
      _log.error('Analytics log failed: $e');
    }
  }

  /// Log session listening minutes
  Future<void> logListeningDuration(int minutes) async {
    try {
      final currentMins = _prefs.getInt(_totalMinutesKey) ?? 0;
      await _prefs.setInt(_totalMinutesKey, currentMins + minutes);

      if (F.isFull && !kIsWeb && Firebase.apps.isNotEmpty) {
        await FirebaseAnalytics.instance.logEvent(
          name: 'listening_session',
          parameters: {'duration_minutes': minutes},
        );
      }
    } catch (_) {}
  }

  /// Log search queries for trend analysis
  Future<void> logSearch(String query) async {
    try {
      if (F.isFull && !kIsWeb && Firebase.apps.isNotEmpty) {
        await FirebaseAnalytics.instance.logSearch(searchTerm: query);
      }
    } catch (_) {}
  }

  /// Get Telemetry Stats for Developer Dashboard
  Map<String, dynamic> getDeveloperStats() {
    final totalPlays = _prefs.getInt(_totalPlaysKey) ?? 0;
    final totalMins = _prefs.getInt(_totalMinutesKey) ?? 0;

    return {
      'totalPlays': totalPlays,
      'totalMinutes': totalMins,
      'activeFlavor': F.appFlavor.name,
      'firebaseEnabled': _prefs.getBool('use_firebase') ?? false,
    };
  }
}
