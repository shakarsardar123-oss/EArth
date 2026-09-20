// tool_execution_context_test.dart — Structural tests for ToolExecutionContext
// Kurdini Sorani RTL first locale (locale='ku'). FAIL-CLOSED design.
// NO Flutter/Dart SDK — structural validation only.

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/tool_execution/domain/models/tool_execution_context.dart';

void main() {
  group('ToolExecutionContext', () {
    test('default context has locale ku and timeoutMs as int', () {
      final context = ToolExecutionContext();
      expect(context.locale, equals('ku'));
      expect(context.timeoutMs, isA<int>());
      expect(context.confirmationDenied, isFalse);
      expect(context.securityCleared, isFalse);
      expect(context.retryAttempt, equals(0));
    });

    test('cancel returns new context with confirmationDenied true', () {
      final original = ToolExecutionContext();
      final cancelled = original.cancel();
      expect(cancelled.confirmationDenied, isTrue);
      expect(identical(original, cancelled), isFalse);
      // immutable: original unchanged
      expect(original.confirmationDenied, isFalse);
    });

    test('withConfirmationDenied returns new context', () {
      final original = ToolExecutionContext();
      final denied = original.withConfirmationDenied();
      expect(denied.confirmationDenied, isTrue);
      expect(original.confirmationDenied, isFalse);
    });

    test('incrementRetry returns new context with retryAttempt+1', () {
      final original = ToolExecutionContext();
      final retried = original.incrementRetry();
      expect(retried.retryAttempt, equals(1));
      expect(original.retryAttempt, equals(0));
      // chain
      final retried2 = retried.incrementRetry();
      expect(retried2.retryAttempt, equals(2));
    });

    test('withSecurityClearance returns new context with reason', () {
      final original = ToolExecutionContext();
      final cleared = original.withSecurityClearance(reason: 'admin_override');
      expect(cleared.securityCleared, isTrue);
      expect(cleared.securityClearanceReason, equals('admin_override'));
      expect(original.securityCleared, isFalse);
    });

    test('throwIfCancelled throws when confirmationDenied is true', () {
      final cancelled = ToolExecutionContext().cancel();
      expect(() => cancelled.throwIfCancelled(), throwsA(isA<ToolExecutionCancelledException>()));
    });

    test('throwIfCancelled does not throw when confirmationDenied is false', () {
      final context = ToolExecutionContext();
      expect(() => context.throwIfCancelled(), returnsNormally);
    });

    test('immutability: all mutation methods return new instances', () {
      final original = ToolExecutionContext();
      final c1 = original.cancel();
      final c2 = original.withConfirmationDenied();
      final c3 = original.incrementRetry();
      final c4 = original.withSecurityClearance(reason: 'test');
      // All must be different instances
      expect(identical(original, c1), isFalse);
      expect(identical(original, c2), isFalse);
      expect(identical(original, c3), isFalse);
      expect(identical(original, c4), isFalse);
      // Original unchanged
      expect(original.confirmationDenied, isFalse);
      expect(original.retryAttempt, equals(0));
      expect(original.securityCleared, isFalse);
    });
  });
}
