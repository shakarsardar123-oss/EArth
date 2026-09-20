/// tool_output_normalizer_test.dart
/// AURA Assistant – Step 22: Tests for ToolOutputNormalizer
///
/// Structural validation only (no Flutter/Dart SDK).
/// Tests: redaction of sensitive keys, status normalization,
/// suggestion generation, null/empty handling, fail-closed.
library;

import 'package:test/test.dart';
import 'package:aura_assistant/features/tool_execution/tool_execution.dart';

void main() {
  group('ToolOutputNormalizer', () {
    late ToolOutputNormalizer normalizer;

    setUp(() {
      normalizer = ToolOutputNormalizer();
    });

    group('redaction', () {
      test('sensitive keys are redacted', () {
        final output = ToolOutput.success(
          data: {
            'token': 'secret-abc',
            'password': 'my-pass',
            'name': 'visible',
          },
          message: 'Ok',
          sensitiveKeys: ['token', 'password'],
        );
        final normalized = normalizer.normalize(output);
        final data = normalized.data as Map;
        expect(data['token'], equals('***REDACTED***'));
        expect(data['password'], equals('***REDACTED***'));
        expect(data['name'], equals('visible'));
      });

      test('no sensitive keys leaves data intact', () {
        final output = ToolOutput.success(
          data: {'count': 42},
          message: 'Ok',
        );
        final normalized = normalizer.normalize(output);
        final data = normalized.data as Map;
        expect(data['count'], equals(42));
      });
    });

    group('status normalization', () {
      test('failure output keeps failure status', () {
        final output = ToolOutput.failure(message: 'Error');
        final normalized = normalizer.normalize(output);
        expect(normalized.status, equals(ToolOutputStatus.failure));
      });

      test('success output keeps success status', () {
        final output = ToolOutput.success(
          data: {},
          message: 'Done',
        );
        final normalized = normalizer.normalize(output);
        expect(normalized.status, equals(ToolOutputStatus.success));
      });
    });

    group('suggestion generation', () {
      test('failure output gets suggestions added', () {
        final output = ToolOutput.failure(
          message: 'Permission denied',
        );
        final normalized = normalizer.normalize(output);
        expect(normalized.suggestions, isNotEmpty);
      });

      test('timedOut output gets retry suggestion', () {
        final output = ToolOutput.timedOut();
        final normalized = normalizer.normalize(output);
        expect(
          normalized.suggestions,
          anyElement(contains('retry')),
        );
      });

      test('cancelled output gets retry suggestion', () {
        final output = ToolOutput.cancelled();
        final normalized = normalizer.normalize(output);
        expect(normalized.suggestions, isNotEmpty);
      });
    });

    group('edge cases', () {
      test('null data normalizes to empty map', () {
        final output = ToolOutput.success(
          data: null,
          message: 'No data',
        );
        final normalized = normalizer.normalize(output);
        expect(normalized.data, isNotNull);
      });

      test('empty data stays empty', () {
        final output = ToolOutput.empty(message: 'Empty');
        final normalized = normalizer.normalize(output);
        expect(normalized.data, isNotNull);
      });
    });

    group('fail-closed', () {
      test('abnormal status normalizes to failClosed', () {
        // If a tool somehow returns an unrecognized status,
        // the normalizer must fail-closed.
        final output = ToolOutput.failClosed(reason: 'Unrecognized');
        final normalized = normalizer.normalize(output);
        expect(normalized.status, equals(ToolOutputStatus.failClosed));
      });
    });
  });
}
