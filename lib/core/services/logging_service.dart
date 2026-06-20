import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum LogLevel {
  debug,
  info,
  warning,
  error,
}

final loggingServiceProvider = Provider<LoggingService>((ref) {
  return LoggingService();
});

class LoggingService {
  void debug(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.debug, message, error, stackTrace);
  }

  void info(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.info, message, error, stackTrace);
  }

  void warning(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.warning, message, error, stackTrace);
  }

  void error(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.error, message, error, stackTrace);
  }

  void _log(LogLevel level, String message, [Object? error, StackTrace? stackTrace]) {
    if (kReleaseMode) {
      return;
    }

    final String timestamp = DateTime.now().toIso8601String();
    final String tag = level.name.toUpperCase();
    final String logMessage = '[$timestamp] [$tag] $message';

    if (error != null) {
      // ignore: avoid_print
      print('$logMessage | Error: $error');
      if (stackTrace != null) {
        // ignore: avoid_print
        print(stackTrace);
      }
    } else {
      // ignore: avoid_print
      print(logMessage);
    }
  }
}
