/// tool_output_test.dart
/// AURA Assistant – Step 22: Tests for ToolOutput
///
/// Structural validation only (no Flutter/Dart SDK).
/// Tests: all factory constructors, status enum, sensitive data,
/// redaction, suggestions.
library;

import 'package:test/test.dart';
import 'package:aura_assistant/features/tool_execution/tool_execution.dart';

void main() {
  group('ToolOutput', () {
    test('.success() creates success output', () {
      final output = ToolOutput.success(
        data: {'result': 'ok'},
        message: 'Completed successfully',
      );
      expect(output.status, equals(ToolOutputStatus.success));
      expect(output.data, isNotNull);
      expect(output.message, equals('Completed successfully'));
    });

    test('.empty() creates empty output', () {
      final output = ToolOutput.empty(message: 'No data');
      expect(output.status, equals(ToolOutputStatus.empty));
    });

    test('.failure() creates failure output', () {
      final output = ToolOutput.failure(message: 'Something went wrong');
      expect(output.status, equals(ToolOutputStatus.failure));
    });

    test('.cancelled() creates cancelled output', () {
      final output = ToolOutput.cancelled(message: 'User cancelled');
      expect(output.status, equals(ToolOutputStatus.cancelled));
    });

    test('.timedOut() creates timed-out output', () {
      final output = ToolOutput.timedOut();
      expect(output.status, equals(ToolOutputStatus.timedOut));
    });

    test('.denied() creates denied output', () {
      final output = ToolOutput.denied(
        reason: 'Insufficient clearance',
      );
      expect(output.status, equals(ToolOutputStatus.denied));
    });

    test('.partial() creates partial output', () {
      final output = ToolOutput.partial(
        data: {'partial': true},
        message: 'Partially completed',
      );
      expect(output.status, equals(ToolOutputStatus.partial));
    });

    test('.failClosed() creates fail-closed output', () {
      final output = ToolOutput.failClosed(
        reason: 'Security gate denied',
      );
      expect(output.status, equals(ToolOutputStatus.failClosed));
    });

    test('sensitive data tracking works', () {
      final output = ToolOutput.success(
        data: {'token': 'abc123', 'name': 'test'},
        message: 'Done',
        sensitiveKeys: ['token'],
      );
      expect(output.sensitiveKeys, contains('token'));
    });

    test('suggestions list is populated', () {
      final output = ToolOutput.failure(
        message: 'Network error',
        suggestions: ['Retry later', 'Check connection'],
      );
      expect(output.suggestions.length, equals(2));
    });

    test('ToolOutputStatus has all 8 values', () {
      expect(ToolOutputStatus.values.length, equals(8));
      expect(ToolOutputStatus.values, contains(ToolOutputStatus.success));
      expect(ToolOutputStatus.values, contains(ToolOutputStatus.empty));
      expect(ToolOutputStatus.values, contains(ToolOutputStatus.failure));
      expect(ToolOutputStatus.values, contains(ToolOutputStatus.cancelled));
      expect(ToolOutputStatus.values, contains(ToolOutputStatus.timedOut));
      expect(ToolOutputStatus.values, contains(ToolOutputStatus.denied));
      expect(ToolOutputStatus.values, contains(ToolOutputStatus.partial));
      expect(ToolOutputStatus.values, contains(ToolOutputStatus.failClosed));
    });
  });
}
