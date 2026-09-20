// tool_output_test.dart — Structural tests for ToolOutput
// FAIL-CLOSED design. All factories require toolId. Structural validation only.

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/tool_execution/domain/models/tool_output.dart';

void main() {
  group('ToolOutput', () {
    test('ToolOutput.success requires toolId', () {
      final output = ToolOutput.success(
        toolId: 'device_tool',
        data: {'flashlight': 'on'},
      );
      expect(output.toolId, equals('device_tool'));
      expect(output.status, equals(ToolOutputStatus.success));
    });

    test('ToolOutput.failure uses errorMessage (not message)', () {
      final output = ToolOutput.failure(
        toolId: 'screen_tool',
        errorMessage: 'Brightness out of range',
      );
      expect(output.status, equals(ToolOutputStatus.failed));
      expect(output.errorMessage, equals('Brightness out of range'));
    });

    test('ToolOutput.failure has optional data param', () {
      final output = ToolOutput.failure(
        toolId: 'screen_tool',
        errorMessage: 'error',
        data: {'partial': 'info'},
      );
      expect(output.data, isNotNull);
    });

    test('ToolOutput.denied uses reason (not errorMessage)', () {
      final output = ToolOutput.denied(
        toolId: 'system_tool',
        reason: 'Insufficient security clearance',
      );
      expect(output.status, equals(ToolOutputStatus.denied));
      expect(output.deniedReason, equals('Insufficient security clearance'));
    });

    test('ToolOutput.cancelled uses message param', () {
      final output = ToolOutput.cancelled(
        toolId: 'voice_tool',
        message: 'User cancelled execution',
      );
      expect(output.status, equals(ToolOutputStatus.cancelled));
    });

    test('ToolOutput.empty has NO data param', () {
      final output = ToolOutput.empty(toolId: 'memory_tool');
      expect(output.status, equals(ToolOutputStatus.empty));
      expect(output.data, isNull);
    });

    test('ToolOutput.timedOut requires toolId', () {
      final output = ToolOutput.timedOut(
        toolId: 'navigation_tool',
        message: 'Execution exceeded timeout',
      );
      expect(output.status, equals(ToolOutputStatus.timedOut));
    });

    test('ToolOutput.partial requires toolId', () {
      final output = ToolOutput.partial(
        toolId: 'media_tool',
        data: {'partial': true},
      );
      expect(output.status, equals(ToolOutputStatus.partial));
    });

    test('ToolOutput.failClosed requires toolId — FAIL-CLOSED', () {
      final output = ToolOutput.failClosed(toolId: 'unknown_tool');
      expect(output.status, equals(ToolOutputStatus.failClosed));
    });

    test('ToolOutputStatus has exactly 8 values', () {
      expect(ToolOutputStatus.values.length, equals(8));
      expect(ToolOutputStatus.values, containsAll([
        ToolOutputStatus.success,
        ToolOutputStatus.failed,
        ToolOutputStatus.cancelled,
        ToolOutputStatus.denied,
        ToolOutputStatus.timedOut,
        ToolOutputStatus.partial,
        ToolOutputStatus.empty,
        ToolOutputStatus.failClosed,
      ]));
    });

    test('containsSensitiveData and sensitiveCategories', () {
      final output = ToolOutput.success(
        toolId: 'test_tool',
        data: {'secret': 'value'},
      );
      // containsSensitiveData is a bool property
      expect(output.containsSensitiveData, isA<bool>());
      // sensitiveCategories is a list of SensitiveDataCategory
      expect(output.sensitiveCategories, isA<List<SensitiveDataCategory>>());
    });

    test('suggestions is non-nullable List<String>', () {
      final output = ToolOutput.success(
        toolId: 'test_tool',
        data: {},
      );
      expect(output.suggestions, isA<List<String>>());
      expect(output.suggestions, isNotNull);
    });

    test('copyWith uses containsSensitiveData', () {
      final original = ToolOutput.success(
        toolId: 'test_tool',
        data: {'key': 'value'},
      );
      final copy = original.copyWith(containsSensitiveData: true);
      expect(copy.containsSensitiveData, isTrue);
    });
  });
}
