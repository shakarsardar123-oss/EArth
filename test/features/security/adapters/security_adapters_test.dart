/// Structural tests for security adapters.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/security/adapters/security_recovery_adapter.dart';
import 'package:aura_assistant/features/security/adapters/security_memory_adapter.dart';
import 'package:aura_assistant/features/security/adapters/security_permission_adapter.dart';

void main() {
  group('SecurityRecoveryAdapter', () {
    test('SecurityRecoveryType enum has expected types', () {
      expect(SecurityRecoveryType.values.length, greaterThanOrEqualTo(4));
    });

    test('SecurityRecoveryResult denialPersists is true on failure', () {
      final result = SecurityRecoveryResult(
        recoveryType: SecurityRecoveryType.retryWithRedaction,
        succeeded: false,
        denialPersists: true,
        message: 'Recovery failed',
      );
      expect(result.denialPersists, isTrue);
    });

    test('canRecoverFailClosed returns false', () {
      final result = SecurityRecoveryResult(
        recoveryType: SecurityRecoveryType.retryWithRedaction,
        succeeded: true,
        denialPersists: false,
        canRecoverFailClosed: false,
        message: 'Recovered',
      );
      expect(result.canRecoverFailClosed, isFalse);
    });
  });

  group('SecurityMemoryAdapter', () {
    test('SecurityMemoryOperation enum has expected operations', () {
      expect(SecurityMemoryOperation.values.length, 5);
      final names = SecurityMemoryOperation.values.map((e) => e.name).toList();
      expect(names, containsAll([
        'remember',
        'recall',
        'search',
        'forget',
        'update',
      ]));
    });

    test('MemoryPrivacyResult failClosedDenial factory', () {
      final result = MemoryPrivacyResult.failClosedDenial(
        operation: SecurityMemoryOperation.recall,
        reason: 'Sensitive data detected',
      );
      expect(result.isDenied, isTrue);
      expect(result.isFailClosed, isTrue);
    });
  });

  group('SecurityPermissionAdapter', () {
    test('PermissionSecurityDecision failClosedDenial factory', () {
      final decision = PermissionSecurityDecision.failClosedDenial(
        permission: 'camera',
        reason: 'Security risk too high',
      );
      expect(decision.isDenied, isTrue);
      expect(decision.isFailClosed, isTrue);
    });

    test('SecurePermissionRequest populates fields', () {
      final request = SecurePermissionRequest(
        permission: 'location',
        riskLevel: 'high',
        context: 'User requested navigation',
      );
      expect(request.permission, 'location');
      expect(request.riskLevel, 'high');
    });
  });
}
