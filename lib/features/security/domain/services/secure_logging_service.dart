/// secure_logging_service.dart
/// AURA Assistant – Step 19: Security & Privacy Hardening
///
/// Domain service interface for secure logging.
/// All logged content MUST be redacted — no raw secrets ever logged.
library;

import 'package:aura_assistant/core/errors/result.dart';
import '../models/security_audit_entry.dart';
import '../models/security_config.dart';
import '../models/security_failure.dart';

/// Log entry severity.
enum LogSeverity {
  debug,
  info,
  warning,
  error,
  critical,
}

/// A secure log entry — all content redacted.
class SecureLogEntry {
  final String id;
  final DateTime timestamp;
  final LogSeverity severity;
  final String tag;
  final String redactedMessage;
  final Map<String, String> safeMetadata;

  const SecureLogEntry({
    required this.id,
    required this.timestamp,
    required this.severity,
    required this.tag,
    required this.redactedMessage,
    this.safeMetadata = const {},
  });

  Map<String, dynamic> toSafeMap() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'severity': severity.name,
        'tag': tag,
        'message': redactedMessage,
        'metadata': safeMetadata,
      };

  @override
  String toString() =>
      'SecureLogEntry(\$severity [\$tag] \$redactedMessage)';
}

/// Abstract domain service for secure logging.
///
/// All content passes through the redaction pipeline before being logged.
/// FAIL CLOSED: if redaction fails, the log entry is dropped entirely
/// rather than risk leaking sensitive data.
abstract class SecureLoggingService {
  /// Log a message with [severity] and [tag].
  ///
  /// [message] will be redacted before logging.
  /// [safeMetadata] keys/values must already be safe — they are NOT
  /// redacted again (assumed pre-sanitized).
  ///
  /// Returns the created [SecureLogEntry] on success, or [SecurityFailure]
  /// if logging failed (e.g., redaction failed → entry dropped).
  Future<SecurityResult<SecureLogEntry>> log(
    LogSeverity severity,
    String tag,
    String message, {
    Map<String, String> safeMetadata = const {},
  });

  /// Record a security audit entry in the log.
  Future<SecurityResult<void>> logAuditEntry(SecurityAuditEntry entry);

  /// Get recent log entries (all redacted).
  Future<SecurityResult<List<SecureLogEntry>>> getRecentEntries({
    int limit = 100,
    LogSeverity? minSeverity,
  });

  /// Clear all log entries older than [retentionDays].
  Future<SecurityResult<int>> purgeOldEntries(int retentionDays);

  /// The current logging mode.
  SecureLoggingMode get currentLoggingMode;

  /// Update the logging mode.
  void setLoggingMode(SecureLoggingMode mode);
}
