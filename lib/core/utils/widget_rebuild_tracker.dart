import 'package:flutter/foundation.dart';
import 'logger.dart';

/// Widget rebuild tracking for performance debugging
/// 
/// Tracks rebuild counts and timing to identify performance bottlenecks.
/// Only active in debug mode - zero overhead in release builds.
class WidgetRebuildTracker {
  static const _enabled = kDebugMode;
  static final _rebuildCounts = <String, int>{};
  static final _rebuildTimes = <String, List<DateTime>>{};
  static final _log = AppLogger('RebuildTracker');

  /// Record a widget rebuild
  /// Call this in the build() method of any widget you want to track
  /// 
  /// Example:
  /// ```dart
  /// class PlayerScreen extends ConsumerWidget {
  ///   @override
  ///   Widget build(BuildContext context, WidgetRef ref) {
  ///     WidgetRebuildTracker.track('PlayerScreen');
  ///     return Scaffold(...);
  ///   }
  /// }
  /// ```
  static void track(String widgetName) {
    if (!_enabled) return;

    _rebuildCounts[widgetName] = (_rebuildCounts[widgetName] ?? 0) + 1;

    _rebuildTimes.putIfAbsent(widgetName, () => []);
    _rebuildTimes[widgetName]!.add(DateTime.now());

    // Keep only last 100 rebuild times to avoid memory buildup
    if (_rebuildTimes[widgetName]!.length > 100) {
      _rebuildTimes[widgetName]!.removeAt(0);
    }
  }

  /// Get rebuild count for a widget
  static int getCount(String widgetName) {
    return _rebuildCounts[widgetName] ?? 0;
  }

  /// Get rebuild frequency (rebuilds per second)
  static double getFrequency(String widgetName) {
    if (!_enabled) return 0;

    final times = _rebuildTimes[widgetName];
    if (times == null || times.length < 2) return 0;

    final duration =
        times.last.difference(times.first).inMilliseconds / 1000.0;
    if (duration == 0) return 0;

    return (times.length - 1) / duration;
  }

  /// Get all rebuild statistics
  static Map<String, ({int count, double frequency})> getStats() {
    if (!_enabled) return {};

    final stats = <String, ({int count, double frequency})>{};
    for (final widgetName in _rebuildCounts.keys) {
      stats[widgetName] = (
        count: _rebuildCounts[widgetName]!,
        frequency: getFrequency(widgetName),
      );
    }
    return stats;
  }

  /// Print rebuild statistics to console
  static void printStats() {
    if (!_enabled) {
      _log.warning('Widget rebuild tracking disabled in release mode');
      return;
    }

    final stats = getStats();
    if (stats.isEmpty) {
      _log.info('No widget rebuild data collected yet');
      return;
    }

    _log.info('Widget Rebuild Statistics:');
    _log.info('─' * 60);

    final sorted = stats.entries.toList()
      ..sort((a, b) => b.value.frequency.compareTo(a.value.frequency));

    for (final entry in sorted) {
      final name = entry.key;
      final count = entry.value.count;
      final freq = entry.value.frequency.toStringAsFixed(2);
      _log.info('$name: $count rebuilds, $freq rebuilds/sec');
    }

    _log.info('─' * 60);
  }

  /// Reset all statistics
  static void reset() {
    if (!_enabled) return;
    _rebuildCounts.clear();
    _rebuildTimes.clear();
    _log.info('Widget rebuild statistics reset');
  }

  /// Get hot widgets (rebuilding frequently)
  /// Returns widgets rebuilding more than threshold times per second
  static List<String> getHotWidgets({double thresholdPerSec = 5.0}) {
    if (!_enabled) return [];

    final stats = getStats();
    return stats.entries
        .where((e) => e.value.frequency > thresholdPerSec)
        .map((e) => '${e.key} (${e.value.frequency.toStringAsFixed(1)}/sec)')
        .toList();
  }

  /// Watch a widget for excessive rebuilds
  /// Logs warning if widget rebuilds too frequently
  static void watchWidget(
    String widgetName, {
    double maxFrequency = 2.0,
  }) {
    if (!_enabled) return;

    final freq = getFrequency(widgetName);
    if (freq > maxFrequency) {
      _log.warning(
          '$widgetName is rebuilding too frequently: ${freq.toStringAsFixed(2)}/sec (max: $maxFrequency/sec)');
    }
  }

  /// Enable detailed logging for a specific widget
  static void enableDetailedTracking(String widgetName) {
    if (!_enabled) return;
    _log.info('Enabled detailed tracking for $widgetName');
  }
}

/// Mixin for easier widget rebuild tracking
/// 
/// Add to any StatelessWidget or ConsumerWidget to track rebuilds
/// 
/// Example:
/// ```dart
/// class PlayerScreen extends ConsumerWidget with RebuildTrackingMixin {
///   static const String _widgetName = 'PlayerScreen';
///   
///   @override
///   Widget build(BuildContext context, WidgetRef ref) {
///     trackRebuild(_widgetName);
///     return Scaffold(...);
///   }
/// }
/// ```
mixin RebuildTrackingMixin {
  void trackRebuild(String widgetName) {
    WidgetRebuildTracker.track(widgetName);
  }
}
