import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Log levels for categorizing messages
enum LogLevel { debug, info, warning, error, fatal }

/// Centralized logging utility for the app.
/// 
/// - In debug mode: All logs printed to console
/// - In release mode: Only warning/error/fatal printed
/// 
/// Usage:
/// ```dart
/// final log = AppLogger('MyClass');
/// log.debug('This is a debug message');
/// log.error('Error occurred', error, stackTrace);
/// ```
class AppLogger {
  final String tag;
  static LogLevel _minLevel = kDebugMode ? LogLevel.debug : LogLevel.warning;

  AppLogger(this.tag);

  /// Set the minimum log level globally
  static void setMinLevel(LogLevel level) {
    _minLevel = level;
  }

  /// Get current minimum log level
  static LogLevel getMinLevel() => _minLevel;

  /// Log a debug message (lowest priority)
  void debug(String message) => _log(LogLevel.debug, message, null, null);

  /// Log an informational message
  void info(String message) => _log(LogLevel.info, message, null, null);

  /// Log a warning message
  void warning(String message) => _log(LogLevel.warning, message, null, null);

  /// Log an error message with optional error object and stack trace
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.error, message, error, stackTrace);
  }

  /// Log a fatal/critical message
  void fatal(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.fatal, message, error, stackTrace);
  }

  /// Internal logging method
  void _log(
    LogLevel level,
    String message,
    Object? error,
    StackTrace? stackTrace,
  ) {
    // Skip if below minimum level
    if (level.index < _minLevel.index) {
      return;
    }

    // Format timestamp
    final isoString = DateTime.now().toIso8601String();
    final timestamp = isoString.contains('T') ? isoString.split('T')[1] : isoString;

    // Build the log message
    final levelStr = level.name.toUpperCase().padRight(7);
    final prefix = '[$timestamp] [$levelStr] [$tag]';
    final formattedMessage = '$prefix $message';

    // Print to console (only in debug mode for non-critical logs)
    if (kDebugMode) {
      debugPrint(formattedMessage);

      if (error != null) {
        debugPrint('  Error: $error');
      }

      if (stackTrace != null && (kDebugMode || level.index >= LogLevel.error.index)) {
        debugPrint('  StackTrace:\n$stackTrace');
      }
    } else if (level.index >= LogLevel.warning.index) {
      // In release mode, print warnings and above
      debugPrint(formattedMessage);
      if (error != null) {
        debugPrint('  Error: $error');
      }
    }

    // Send to Crashlytics for errors and fatal messages
    if (level.index >= LogLevel.error.index) {
      _sendToCrashlytics(message, error, stackTrace, level);
    }
  }

  /// Send error/fatal logs to Firebase Crashlytics for production monitoring
  /// 
  /// This helps track critical issues in production without exposing sensitive data.
  /// Only errors and fatal messages are sent to reduce noise.
  void _sendToCrashlytics(
    String message,
    Object? error,
    StackTrace? stackTrace,
    LogLevel level,
  ) {
    try {
      final crashlytics = FirebaseCrashlytics.instance;
      
      // Build the error message
      final errorMessage = '$tag: $message${error != null ? ' - $error' : ''}';
      
      // Record the error with stack trace
      if (error != null && stackTrace != null) {
        crashlytics.recordError(
          error,
          stackTrace,
          reason: errorMessage,
          fatal: level == LogLevel.fatal,
        );
      } else if (error != null) {
        // Error without stack trace
        crashlytics.recordError(
          Exception(errorMessage),
          StackTrace.current,
          reason: 'Logged error: ${level.name.toUpperCase()}',
          fatal: level == LogLevel.fatal,
        );
      } else {
        // Message without error object - log as breadcrumb
        crashlytics.log('[$tag] ${level.name.toUpperCase()}: $message');
      }
    } catch (e) {
      // Silently fail - don't want logging to cause crashes
      debugPrint('Failed to send to Crashlytics: $e');
    }
  }
}
