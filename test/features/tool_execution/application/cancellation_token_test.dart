/// cancellation_token_test.dart
/// AURA Assistant – Step 22: Tests for CancellationToken
///
/// Structural validation only (no Flutter/Dart SDK).
/// Tests: initial state, cancel(), isCancelled, reason,
/// onCancellation callback, ToolExecutionCancelledException.
library;

import 'package:test/test.dart';
import 'package:aura_assistant/features/tool_execution/tool_execution.dart';

void main() {
  group('CancellationToken', () {
    test('initial state is not cancelled', () {
      final token = CancellationToken();
      expect(token.isCancelled, isFalse);
      expect(token.reason, isNull);
    });

    test('cancel() sets isCancelled and reason', () {
      final token = CancellationToken();
      token.cancel('User pressed stop');
      expect(token.isCancelled, isTrue);
      expect(token.reason, equals('User pressed stop'));
    });

    test('cancel() without reason sets empty string', () {
      final token = CancellationToken();
      token.cancel();
      expect(token.isCancelled, isTrue);
      expect(token.reason, isEmpty);
    });

    test('onCancellation callback is invoked on cancel', () {
      var callbackInvoked = false;
      String? callbackReason;
      final token = CancellationToken(
        onCancellation: (reason) {
          callbackInvoked = true;
          callbackReason = reason;
        },
      );
      token.cancel('Timeout');
      expect(callbackInvoked, isTrue);
      expect(callbackReason, equals('Timeout'));
    });

    test('multiple cancel() calls keep first reason', () {
      final token = CancellationToken();
      token.cancel('First');
      token.cancel('Second');
      expect(token.reason, equals('First'));
    });

    test('throwIfCancelled() throws when cancelled', () {
      final token = CancellationToken();
      token.cancel('Aborted');
      expect(
        () => token.throwIfCancelled(),
        throwsA(isA<ToolExecutionCancelledException>()),
      );
    });

    test('throwIfCancelled() does not throw when not cancelled', () {
      final token = CancellationToken();
      expect(() => token.throwIfCancelled(), returnsNormally);
    });
  });

  group('ToolExecutionCancelledException', () {
    test('carries cancellation reason', () {
      final exception = ToolExecutionCancelledException('User stopped');
      expect(exception.message, equals('User stopped'));
      expect(exception.toString(), contains('User stopped'));
    });

    test('implements Exception', () {
      final exception = ToolExecutionCancelledException('Test');
      expect(exception, isA<Exception>());
    });
  });
}
