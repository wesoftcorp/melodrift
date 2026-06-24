import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;

/// Utility for memory profiling and performance tracking
/// 
/// Marks key operations for analysis in DevTools Timeline.
/// Only active in debug mode - completely eliminated in release.
class MemoryProfiler {
  static const _enabled = kDebugMode;

  /// Mark the start of an operation for profiling
  /// 
  /// Example:
  /// ```dart
  /// MemoryProfiler.startMark('load_playlist');
  /// // ... do work ...
  /// MemoryProfiler.endMark('load_playlist');
  /// ```
  static void startMark(String name) {
    if (!_enabled) return;
    developer.Timeline.startSync('$name.start');
  }

  /// Mark the end of an operation
  static void endMark(String name) {
    if (!_enabled) return;
    developer.Timeline.finishSync();
  }

  /// Instant mark for point-in-time events
  /// 
  /// Use for one-off events that don't have duration:
  /// ```dart
  /// MemoryProfiler.instant('queue_updated', {'count': 100});
  /// ```
  static void instant(String name, [Map<String, dynamic>? arguments]) {
    if (!_enabled) return;
    developer.Timeline.instantSync(name, arguments: arguments);
  }

  /// Profile an async operation and return the result
  /// 
  /// Example:
  /// ```dart
  /// final result = await MemoryProfiler.profileAsync(
  ///   'fetch_songs',
  ///   () => repository.getSongs(),
  /// );
  /// ```
  static Future<T> profileAsync<T>(
    String name,
    Future<T> Function() operation,
  ) async {
    if (!_enabled) return operation();

    developer.Timeline.startSync('$name.async');
    try {
      final result = await operation();
      developer.Timeline.finishSync();
      return result;
    } catch (e) {
      developer.Timeline.finishSync();
      rethrow;
    }
  }

  /// Profile a sync operation and return the result
  /// 
  /// Example:
  /// ```dart
  /// final result = MemoryProfiler.profileSync(
  ///   'parse_json',
  ///   () => jsonDecode(data),
  /// );
  /// ```
  static T profileSync<T>(
    String name,
    T Function() operation,
  ) {
    if (!_enabled) return operation();

    developer.Timeline.startSync('$name.sync');
    try {
      final result = operation();
      developer.Timeline.finishSync();
      return result;
    } catch (e) {
      developer.Timeline.finishSync();
      rethrow;
    }
  }
}
