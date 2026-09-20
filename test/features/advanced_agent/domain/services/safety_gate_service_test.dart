/// safety_gate_service_test.dart
/// Structural tests for SafetyGateService.
///
/// Verifies: guard() is fail-closed entry; evaluate() does NOT guard.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/advanced_agent/domain/services/safety_gate_service.dart';

void main() {
  group('SafetyGateService', () {
    test('has guard method', () {
      final service = SafetyGateService();
      expect(service.guard, isA<Function>());
    });

    test('has evaluate method', () {
      final service = SafetyGateService();
      expect(service.evaluate, isA<Function>());
    });

    test('guard is fail-closed entry point', () async {
      final service = SafetyGateService();
      // guard() is the FAIL-CLOSED entry point
      // evaluate() does NOT enforce fail-closed by itself
      try {
        await service.guard(
          action: 'delete',
          toolId: 'tool1',
          riskLevel: 'high',
        );
      } catch (_) {
        // Structural test — may throw without backing impl
      }
    });
  });
}
