import 'dart:developer' as developer;

/// Simple logging wrapper for development and future production use.
///
/// Phase 1 uses [developer.log]; production phases may integrate
/// a remote logging service.
class AppLogger {
  AppLogger._();

  static void debug(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log('DEBUG', message, tag: tag, error: error, stackTrace: stackTrace);
  }

  static void info(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log('INFO', message, tag: tag, error: error, stackTrace: stackTrace);
  }

  static void warning(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log('WARNING', message, tag: tag, error: error, stackTrace: stackTrace);
  }

  static void error(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log('ERROR', message, tag: tag, error: error, stackTrace: stackTrace);
  }

  static void _log(
    String level,
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final prefix = tag != null ? '[$tag] ' : '';
    developer.log(
      '$prefix$level: $message',
      error: error,
      stackTrace: stackTrace,
      level: _levelValue(level),
    );
  }

  static int _levelValue(String level) {
    switch (level) {
      case 'DEBUG':
        return 500;
      case 'INFO':
        return 800;
      case 'WARNING':
        return 900;
      case 'ERROR':
        return 1000;
      default:
        return 800;
    }
  }
}
