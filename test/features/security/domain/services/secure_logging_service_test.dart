/// Structural tests for SecureLoggingService domain contract.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/security/domain/services/secure_logging_service.dart';

void main() {
  group('LogSeverity', () {
    test('has expected severity levels', () {
      expect(LogSeverity.values.length, greaterThanOrEqualTo(4));
      expect(LogSeverity.values, containsAll([
        LogSeverity.debug,
        LogSeverity.info,
        LogSeverity.warning,
        LogSeverity.error,
      ]));
    });
  });

  group('SecureLogEntry', () {
    test('constructor populates all fields', () {
      final entry = SecureLogEntry(
        severity: LogSeverity.info,
        category: 'security',
        message: 'Action allowed',
        timestamp: DateTime.now(),
        metadata: {'action': 'read_file'},
      );
      expect(entry.severity, LogSeverity.info);
      expect(entry.category, 'security');
      expect(entry.message, 'Action allowed');
    });

    test('toSafeMap provides exportable entry', () {
      final entry = SecureLogEntry(
        severity: LogSeverity.warning,
        category: 'redaction',
        message: 'Redaction applied',
        timestamp: DateTime(2025, 6, 15),
      );
      final map = entry.toSafeMap();
      expect(map, isNotNull);
      expect(map['severity'], isNotNull);
      expect(map['category'], 'redaction');
    });
  });
}
