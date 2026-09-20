/// Structural tests for SecurityVerdict domain model.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/security/domain/models/security_verdict.dart';

void main() {
  group('SecurityVerdict', () {
    test('allowed factory creates allowed verdict', () {
      final verdict = SecurityVerdict.allowed(reason: 'action_safe');
      expect(verdict.isDenied, isFalse);
      expect(verdict.isExplicitlyDenied, isFalse);
      expect(verdict.isFailClosedDenial, isFalse);
      expect(verdict.displayReason, 'action_safe');
    });

    test('denied factory creates explicitly denied verdict', () {
      final verdict = SecurityVerdict.denied(reason: 'prohibited_action');
      expect(verdict.isDenied, isTrue);
      expect(verdict.isExplicitlyDenied, isTrue);
      expect(verdict.isFailClosedDenial, isFalse);
      expect(verdict.displayReason, 'prohibited_action');
    });

    test('failClosed factory creates fail-closed denial', () {
      final verdict = SecurityVerdict.failClosed(reason: 'ambiguous_state');
      expect(verdict.isDenied, isTrue);
      expect(verdict.isExplicitlyDenied, isFalse);
      expect(verdict.isFailClosedDenial, isTrue);
      expect(verdict.displayReason, 'ambiguous_state');
    });

    test('fail-closed denial is still a denial', () {
      final verdict = SecurityVerdict.failClosed(reason: 'inconclusive');
      expect(verdict.isDenied, isTrue);
    });

    test('displayReason is never null', () {
      final allowed = SecurityVerdict.allowed(reason: 'ok');
      final denied = SecurityVerdict.denied(reason: 'no');
      final failClosed = SecurityVerdict.failClosed(reason: 'maybe');
      expect(allowed.displayReason, isNotNull);
      expect(denied.displayReason, isNotNull);
      expect(failClosed.displayReason, isNotNull);
    });
  });
}
