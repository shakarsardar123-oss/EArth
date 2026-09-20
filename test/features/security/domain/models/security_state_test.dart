/// Structural tests for SecurityState and SecurityAuditEvent.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/security/domain/models/security_state.dart';
import 'package:aura_assistant/features/security/domain/models/security_config.dart';

void main() {
  group('SecurityState', () {
    test('initial factory creates default state', () {
      final state = SecurityState.initial();
      expect(state.config, isNotNull);
      expect(state.isInitialized, isFalse);
      expect(state.secretsDetected, 0);
      expect(state.blockedActions, 0);
    });

    test('copyWith updates fields', () {
      final base = SecurityState.initial();
      final updated = base.copyWith(secretsDetected: 5);
      expect(updated.secretsDetected, 5);
      expect(updated.blockedActions, base.blockedActions);
    });

    test('copyWith clear* flags reset nullable fields', () {
      final base = SecurityState.initial();
      final cleared = base.copyWith(clearActiveOperation: true);
      expect(cleared.activeOperation, isNull);
    });

    test('is @immutable', () {
      final state = SecurityState.initial();
      expect(state.hashCode, isNotNull);
    });
  });

  group('SecurityAuditEvent', () {
    test('constructor populates fields', () {
      final event = SecurityAuditEvent(
        type: SecurityAuditType.secretDetected,
        severity: SecurityEventSeverity.critical,
        description: 'API key detected',
        timestamp: DateTime.now(),
      );
      expect(event.type, SecurityAuditType.secretDetected);
      expect(event.severity, SecurityEventSeverity.critical);
      expect(event.description, 'API key detected');
    });
  });

  group('SecurityEventSeverity', () {
    test('has expected severity levels', () {
      expect(SecurityEventSeverity.values.length, greaterThanOrEqualTo(4));
      expect(SecurityEventSeverity.values, containsAll([
        SecurityEventSeverity.critical,
        SecurityEventSeverity.high,
        SecurityEventSeverity.medium,
        SecurityEventSeverity.low,
      ]));
    });
  });
}
