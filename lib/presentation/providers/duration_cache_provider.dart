import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/logger.dart';

/// Duration cache to prevent redundant API calls
/// 
/// Caches video durations in memory with automatic cleanup
class DurationCache {
  static final _log = AppLogger('DurationCache');
  static final _cache = <String, Duration>{};
  static const _maxCacheSize = 1000; // Max 1000 durations

  /// Get cached duration
  static Duration? get(String videoId) {
    return _cache[videoId];
  }

  /// Set duration in cache
  static void set(String videoId, Duration duration) {
    if (_cache.length >= _maxCacheSize) {
      // Remove oldest entry (first one added)
      _cache.remove(_cache.keys.first);
      _log.debug('Duration cache full, removed oldest entry');
    }

    _cache[videoId] = duration;
    _log.debug('Cached duration for $videoId: ${duration.inSeconds}s');
  }

  /// Clear all cached durations
  static void clear() {
    _cache.clear();
    _log.info('Duration cache cleared');
  }

  /// Get cache statistics
  static ({int size, int maxSize}) getStats() {
    return (size: _cache.length, maxSize: _maxCacheSize);
  }
}

/// Riverpod provider for duration caching
final durationCacheProvider = StateProvider<Map<String, Duration>>((ref) {
  return _DurationCacheNotifier()._cache;
});

class _DurationCacheNotifier {
  final _cache = <String, Duration>{};
  final _log = AppLogger('DurationCacheNotifier');
  static const _maxCacheSize = 1000;

  Duration? getDuration(String videoId) {
    return _cache[videoId];
  }

  void cacheDuration(String videoId, Duration duration) {
    if (_cache.length >= _maxCacheSize) {
      _cache.remove(_cache.keys.first);
      _log.debug('Duration cache full, evicted oldest');
    }

    _cache[videoId] = duration;
    _log.debug('Cached duration: $videoId = ${duration.inSeconds}s');
  }

  void clear() {
    _cache.clear();
    _log.info('Duration cache cleared');
  }

  int get cacheSize => _cache.length;
}

/// Provider to get duration with caching
/// 
/// Returns cached duration if available, otherwise returns Duration.zero
/// Call cacheDuration() after fetching from API
final videoDurationProvider = Provider.family<Duration, String>((ref, videoId) {
  // Check cache first
  final cached = DurationCache.get(videoId);
  if (cached != null) {
    return cached;
  }

  // Default: will be updated when duration is resolved
  return Duration.zero;
});

/// Service for managing duration caching
class DurationCachingService {
  final _log = AppLogger('DurationCachingService');

  /// Cache a resolved duration
  /// Call this after successfully fetching duration from YouTube API
  void cacheDuration(String videoId, Duration duration) {
    DurationCache.set(videoId, duration);
  }

  /// Get duration from cache
  Duration? getDuration(String videoId) {
    return DurationCache.get(videoId);
  }

  /// Pre-cache durations for upcoming songs
  /// 
  /// Useful for pre-loading metadata in background
  Future<void> preCacheDurations(
    List<String> videoIds,
    Future<Duration> Function(String) fetchDuration,
  ) async {
    _log.debug('Pre-caching durations for ${videoIds.length} videos');

    for (final videoId in videoIds) {
      // Skip if already cached
      if (DurationCache.get(videoId) != null) continue;

      try {
        final duration = await fetchDuration(videoId).timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            _log.warning('Duration fetch timeout for $videoId');
            return Duration.zero;
          },
        );

        if (duration.inSeconds > 0) {
          DurationCache.set(videoId, duration);
        }
      } catch (e) {
        _log.warning('Failed to pre-cache duration for $videoId: $e');
        // Continue with next - pre-caching is best-effort
      }
    }

    _log.debug('Pre-caching complete. Cache size: ${DurationCache.getStats().size}');
  }

  /// Get cache statistics
  String getCacheStats() {
    final stats = DurationCache.getStats();
    return 'Duration cache: ${stats.size}/${stats.maxSize} entries';
  }

  /// Clear cache (e.g., on low memory)
  void clearCache() {
    DurationCache.clear();
    _log.info('Duration cache cleared');
  }
}

/// Global duration caching service instance
final durationCachingService = DurationCachingService();
