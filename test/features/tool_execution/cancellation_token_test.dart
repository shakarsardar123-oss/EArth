// cancellation_token_test.dart — Structural tests for CancellationToken
// CancellationToken.cancel() takes NO arguments. Structural validation only.

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/tool_execution/infrastructure/cancellation_token.dart';

void main() {
  group('CancellationToken', () {
    test('initial state is not cancelled', () {
      final token = CancellationToken();
      expect(token.isCancelled, isFalse);
    });

    test('cancel() takes no arguments and sets isCancelled to true', () {
      final token = CancellationToken();
      token.cancel();
      expect(token.isCancelled, isTrue);
    });

    test('cancel() is idempotent', () {
      final token = CancellationToken();
      token.cancel();
      token.cancel(); // second call should not throw
      expect(token.isCancelled, isTrue);
    });

    test('throwIfCancelled does not throw when not cancelled', () {
      final token = CancellationToken();
      expect(() => token.throwIfCancelled(), returnsNormally);
    });

    test('throwIfCancelled throws when cancelled', () {
      final token = CancellationToken();
      token.cancel();
      expect(
        () => token.throwIfCancelled(),
        throwsA(isA<ToolExecutionCancelledException>()),
      );
    });

    test('multiple tokens are independent', () {
      final token1 = CancellationToken();
      final token2 = CancellationToken();
      token1.cancel();
      expect(token1.isCancelled, isTrue);
      expect(token2.isCancelled, isFalse);
    });
  });
}
