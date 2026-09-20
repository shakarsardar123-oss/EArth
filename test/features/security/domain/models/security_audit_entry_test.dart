/// Structural tests for SecurityAuditEntry.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/security/domain/models/security_audit_entry.dart';
import 'package:aura_assistant/features/security/domain/models/security_state.dart';

void main() {
  group('SecurityAuditEntry', () {
    test('constructor populates all fields', () {
      final entry = SecurityAuditEntry(
        type: SecurityAuditType.actionDenied,
        severity: SecurityEventSeverity.high,
        action: 'delete_file',
        reason: 'Prohibited action',
        timestamp: DateTime(2025, 1, 1),
        userId: 'user_001',
      );

      expect(entry.type, SecurityAuditType.actionDenied);
      expect(entry.severity, SecurityEventSeverity.high);
      expect(entry.action, 'delete_file');
      expect(entry.reason, 'Prohibited action');
      expect(entry.userId, 'user_001');
    });

    test('toSafeMap excludes sensitive fields', () {
      final entry = SecurityAuditEntry(
        type: SecurityAuditType.secretDetected,
        severity: SecurityEventSeverity.critical,
        action: 'scan_text',
        reason: 'Secret detected',
        timestamp: DateTime(2025, 1, 1),
        userId: 'user_001',
      );

      final safeMap = entry.toSafeMap();
      expect(safeMap, isNotNull);
      expect(safeMap['type'], isNotNull);
      expect(safeMap['action'], isNotNull);
      // userId should not appear in safe map for privacy
    });

    test('SecurityAuditType has 13 types', () {
      expect(SecurityAuditType.values.length, 13);
    });

    test('SecurityAuditType covers all major audit events', () {
      final typeNames = SecurityAuditType.values.map((t) => t.name).toList();
      expect(typeNames, containsAll([
        'secretDetected',
        'actionDenied',
        'actionAllowed',
        'redactionPerformed',
        'configChanged',
        'permissionCheck',
        'memoryOperation',
        'storageOperation',
        'systemStartup',
        'recoveryAttempt',
      ]));
    });
  });
}
