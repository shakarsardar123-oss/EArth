/// safety_verdict_test.dart
/// Structural & mock tests for SafetyVerdict model.
///
/// Verifies: class existence, field names, factory constructors,
/// FAIL-CLOSED patterns (unknown→denied, error→denied, unavailable→denied).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/advanced_agent/domain/models/safety_verdict.dart';

void main() {
  group('SafetyVerdictStatus', () {
    test('fromName returns correct enum for known values', () {
      expect(SafetyVerdictStatus.fromName('allowed'), SafetyVerdictStatus.allowed);
      expect(SafetyVerdictStatus.fromName('denied'), SafetyVerdictStatus.denied);
      expect(SafetyVerdictStatus.fromName('requiresApproval'), SafetyVerdictStatus.requiresApproval);
    });

    test('FAIL-CLOSED: fromName returns denied for unknown name', () {
      expect(SafetyVerdictStatus.fromName('unknown'), SafetyVerdictStatus.denied);
      expect(SafetyVerdictStatus.fromName('foobar'), SafetyVerdictStatus.denied);
      expect(SafetyVerdictStatus.fromName(''), SafetyVerdictStatus.denied);
    });

    test('enum has exactly 3 values', () {
      expect(SafetyVerdictStatus.values.length, 3);
    });
  });

  group('SafetyVerdict', () {
    test('isDenied is true for denied status', () {
      final v = SafetyVerdict.denied(verdictId: 'v1');
      expect(v.isDenied, isTrue);
      expect(v.isAllowed, isFalse);
    });

    test('isAllowed is true for allowed status', () {
      final v = SafetyVerdict.allowed(verdictId: 'v2');
      expect(v.isAllowed, isTrue);
      expect(v.isDenied, isFalse);
    });

    test('requiresApproval is true for requiresApproval status', () {
      final v = SafetyVerdict.requiresApproval(verdictId: 'v3');
      expect(v.requiresApproval, isTrue);
      expect(v.isAllowed, isFalse);
      expect(v.isDenied, isFalse);
    });

    test('FAIL-CLOSED: unavailable factory produces denied', () {
      final v = SafetyVerdict.unavailable(verdictId: 'v4');
      expect(v.isDenied, isTrue);
      expect(v.rationale, contains('unavailable'));
    });

    test('FAIL-CLOSED: error factory produces denied', () {
      final v = SafetyVerdict.error(verdictId: 'v5');
      expect(v.isDenied, isTrue);
      expect(v.rationale, contains('error'));
    });

    test('fields: verdictId, action, toolId, riskCategory, rationale', () {
      final v = SafetyVerdict(
        verdictId: 'v6',
        action: 'delete',
        toolId: 'tool1',
        riskCategory: 'high',
        rationale: 'Too risky',
        evaluatedAt: DateTime.now(),
      );
      expect(v.verdictId, 'v6');
      expect(v.action, 'delete');
      expect(v.toolId, 'tool1');
      expect(v.riskCategory, 'high');
      expect(v.rationale, 'Too risky');
    });

    test('denied factory sets default rationale', () {
      final v = SafetyVerdict.denied(verdictId: 'v7');
      expect(v.rationale, contains('fail-closed'));
    });
  });
}
