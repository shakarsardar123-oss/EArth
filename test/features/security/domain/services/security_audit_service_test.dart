/// Structural tests for SecurityAuditService domain contract.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/security/domain/services/security_audit_service.dart';

void main() {
  group('AuditQuery', () {
    test('constructor populates fields', () {
      final query = AuditQuery(
        typeFilter: 'actionDenied',
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 12, 31),
        limit: 100,
      );
      expect(query.typeFilter, 'actionDenied');
      expect(query.limit, 100);
    });
  });

  group('AuditSummary', () {
    test('constructor populates fields', () {
      final summary = AuditSummary(
        totalEvents: 42,
        blockedEvents: 10,
        allowedEvents: 32,
        criticalEvents: 3,
      );
      expect(summary.totalEvents, 42);
      expect(summary.blockedEvents, 10);
      expect(summary.allowedEvents, 32);
      expect(summary.criticalEvents, 3);
    });
  });
}
