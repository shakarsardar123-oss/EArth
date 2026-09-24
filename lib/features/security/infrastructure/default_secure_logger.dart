/// default_secure_logger.dart
/// AURA Assistant – Step 19: Security & Privacy Hardening
///
/// Default infrastructure implementation of SecureLoggingService.
/// All log messages pass through the redaction pipeline.
///
/// FAIL CLOSED: if redaction fails, the log entry is DROPPED entirely
/// rather than risk leaking sensitive data.
library;

import 'package:texo/core/errors/result.dart' show Result, Success, Failure;
import '../domain/models/security_audit_entry.dart';
import '../domain/models/security_config.dart';
import '../domain/models/security_failure.dart';
import '../domain/models/security_state.dart';
import '../domain/services/secure_logging_service.dart';
import '../domain/services/sensitive_data_redactor.dart';
import '../../../core/errors/result.dart';

/// Default secure logger implementation.
///
/// All messages are redacted before logging.
/// Supports multiple logging modes from disabled to debug.
class DefaultSecureLogger implements SecureLoggingService {
  SecureLoggingMode _loggingMode = SecureLoggingMode.redactedOnly;
  final SensitiveDataRedactor _redactor;
  final List<SecureLogEntry> _entries = [];
  static const int _maxEntries = 1000;

  DefaultSecureLogger({
    required SensitiveDataRedactor redactor,
    SecureLoggingMode loggingMode = SecureLoggingMode.redactedOnly,
  })  : _redactor = redactor,
        _loggingMode = loggingMode;

  @override
  SecureLoggingMode get currentLoggingMode => _loggingMode;

  @override
  void setLoggingMode(SecureLoggingMode mode) {
    _loggingMode = mode;
  }

  @override
  Future<SecurityResult<SecureLogEntry>> log(
    LogSeverity severity,
    String tag,
    String message, {
    Map<String, String> safeMetadata = const {},
  }) async {
    // FAIL CLOSED: if logging is disabled, drop the entry silently
    if (_loggingMode == SecureLoggingMode.disabled) {
      return SecurityFailure.configApplicationFailed(
        action: 'log',
        cause: 'Logging is disabled by configuration',
      ).asFailure<SecureLogEntry>();
    }

    try {
      // If metadata-only mode, strip the message entirely
      if (_loggingMode == SecureLoggingMode.metadataOnly) {
        final entry = SecureLogEntry(
          id: _generateId(),
          timestamp: DateTime.now(),
          severity: severity,
          tag: tag,
          redactedMessage: '[METADATA ONLY]',
          safeMetadata: safeMetadata,
        );
        _addEntry(entry);
        return Success(entry);
      }

      // For all other modes, redact the message
      final redactionResult = await _redactor.redact(message);

      return redactionResult.fold(
        onSuccess: (result) {
          final entry = SecureLogEntry(
            id: _generateId(),
            timestamp: DateTime.now(),
            severity: severity,
            tag: tag,
            redactedMessage: _loggingMode == SecureLoggingMode.debugRedacted
                ? '[DEBUG] ${result.redactedContent}'
                : result.redactedContent,
            safeMetadata: safeMetadata,
          );
          _addEntry(entry);
          return Success(entry);
        },
        onFailure: (failure) {
          // FAIL CLOSED: if redaction fails, DROP the entry entirely
          return SecurityFailure.configApplicationFailed(
            action: 'log',
            cause: 'Redaction failed — entry dropped for safety',
          ).asFailure<SecureLogEntry>();
        },
      );
    } catch (e) {
      // FAIL CLOSED: on any unexpected error, drop the entry
      return SecurityFailure.configApplicationFailed(
        action: 'log',
        cause: 'Unexpected error — entry dropped for safety',
      ).asFailure<SecureLogEntry>();
    }
  }

  @override
  Future<SecurityResult<void>> logAuditEntry(
    SecurityAuditEntry entry,
  ) async {
    if (_loggingMode == SecureLoggingMode.disabled) {
      return SecurityFailure.configApplicationFailed(
        action: 'logAuditEntry',
        cause: 'Logging is disabled by configuration',
      ).asFailure<void>();
    }

    try {
      final logEntry = SecureLogEntry(
        id: _generateId(),
        timestamp: entry.timestamp,
        severity: _mapSeverity(entry.severity),
        tag: 'audit.${entry.type.name}',
        redactedMessage: entry.redactedDescription,
        safeMetadata: entry.safeMetadata,
      );
      _addEntry(logEntry);
      return Success(null);
    } catch (_) {
      return SecurityFailure.configApplicationFailed(
        action: 'logAuditEntry',
        cause: 'Unexpected error — entry dropped for safety',
      ).asFailure<void>();
    }
  }

  @override
  Future<SecurityResult<List<SecureLogEntry>>> getRecentEntries({
    int limit = 100,
    LogSeverity? minSeverity,
  }) async {
    try {
      var entries = _entries;
      if (minSeverity != null) {
        final minIndex = LogSeverity.values.indexOf(minSeverity);
        entries = entries
            .where((e) =>
                LogSeverity.values.indexOf(e.severity) >= minIndex)
            .toList();
      }
      return Success(entries.take(limit).toList());
    } catch (_) {
      return SecurityFailure.configApplicationFailed(
        action: 'getRecentEntries',
        cause: 'Failed to retrieve entries',
      ).asFailure<List<SecureLogEntry>>();
    }
  }

  @override
  Future<SecurityResult<int>> purgeOldEntries(int retentionDays) async {
    try {
      final cutoff = DateTime.now().subtract(
        Duration(days: retentionDays),
      );
      final removed = _entries
          .where((e) => e.timestamp.isBefore(cutoff))
          .length;
      _entries.removeWhere((e) => e.timestamp.isBefore(cutoff));
      return Success(removed);
    } catch (_) {
      return SecurityFailure.configApplicationFailed(
        action: 'purgeOldEntries',
        cause: 'Failed to purge entries',
      ).asFailure<int>();
    }
  }

  // ─── Private helpers ─────────────────────────────────────────────

  void _addEntry(SecureLogEntry entry) {
    _entries.add(entry);
    if (_entries.length > _maxEntries) {
      _entries.removeRange(0, _entries.length - _maxEntries);
    }
  }

  String _generateId() =>
      'log_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';

  LogSeverity _mapSeverity(SecurityEventSeverity severity) {
    switch (severity) {
      case SecurityEventSeverity.info:
        return LogSeverity.info;
      case SecurityEventSeverity.warning:
        return LogSeverity.warning;
      case SecurityEventSeverity.critical:
        return LogSeverity.critical;
    }
  }
}
