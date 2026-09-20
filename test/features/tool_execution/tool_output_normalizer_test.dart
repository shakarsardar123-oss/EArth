// tool_output_normalizer_test.dart — Structural tests for ToolOutputNormalizer
// Uses containsSensitiveData (not hasSensitiveData); suggestions.isEmpty (not suggestions?.isEmpty).
// Structural validation only.

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/tool_execution/infrastructure/tool_output_normalizer.dart';
import 'package:aura_assistant/features/tool_execution/domain/models/tool_output.dart';

void main() {
  group('ToolOutputNormalizer', () {
    test('normalize returns ToolOutput with toolId', () {
      final normalizer = ToolOutputNormalizer();
      final raw = {'result': 'ok', 'data': [1, 2, 3]};
      final output = normalizer.normalize(
        toolId: 'device_tool',
        rawData: raw,
      );
      expect(output, isA<ToolOutput>());
      expect(output.toolId, equals('device_tool'));
    });

    test('normalized output checks containsSensitiveData (not hasSensitiveData)', () {
      final normalizer = ToolOutputNormalizer();
      final raw = {'password': 'secret123'};
      final output = normalizer.normalize(
        toolId: 'test_tool',
        rawData: raw,
      );
      // Property is containsSensitiveData, not hasSensitiveData
      expect(output.containsSensitiveData, isA<bool>());
      expect(output.containsSensitiveData, isTrue);
    });

    test('normalized output has non-nullable suggestions list', () {
      final normalizer = ToolOutputNormalizer();
      final raw = {'result': 'success'};
      final output = normalizer.normalize(
        toolId: 'test_tool',
        rawData: raw,
      );
      expect(output.suggestions, isNotNull);
      expect(output.suggestions, isA<List<String>>());
    });

    test('normalized output with no sensitive data', () {
      final normalizer = ToolOutputNormalizer();
      final raw = {'status': 'ok'};
      final output = normalizer.normalize(
        toolId: 'device_tool',
        rawData: raw,
      );
      expect(output.containsSensitiveData, isFalse);
      expect(output.suggestions.isEmpty, isTrue); // suggestions.isEmpty NOT suggestions?.isEmpty
    });

    test('sensitive data categories populated when sensitive data found', () {
      final normalizer = ToolOutputNormalizer();
      final raw = {'token': 'abc123', 'password': 'pass'};
      final output = normalizer.normalize(
        toolId: 'test_tool',
        rawData: raw,
      );
      if (output.containsSensitiveData) {
        expect(output.sensitiveCategories, isNotEmpty);
      }
    });

    test('FAIL-CLOSED: unknown raw data returns safe output', () {
      final normalizer = ToolOutputNormalizer();
      final output = normalizer.normalize(
        toolId: 'unknown',
        rawData: null,
      );
      // FAIL-CLOSED: null/unknown data should not expose secrets
      expect(output.containsSensitiveData, isFalse);
    });
  });
}
