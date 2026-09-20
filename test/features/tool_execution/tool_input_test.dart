// tool_input_test.dart — Structural tests for ToolInput
// FAIL-CLOSED design. Structural validation only.

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/tool_execution/domain/models/tool_input.dart';

void main() {
  group('ToolInput', () {
    test('ToolInput.valid creates valid input with defaults', () {
      final input = ToolInput.valid(
        toolId: 'device_tool',
        params: {'action': 'flashlight_on'},
      );
      expect(input.toolId, equals('device_tool'));
      expect(input.isValid, isTrue);
      expect(input.wasSanitized, isFalse);
      expect(input.source, equals('user'));
    });

    test('ToolInput.valid with wasSanitized and source', () {
      final input = ToolInput.valid(
        toolId: 'voice_tool',
        params: {'text': 'hello'},
        wasSanitized: true,
        source: 'automation',
      );
      expect(input.wasSanitized, isTrue);
      expect(input.source, equals('automation'));
    });

    test('ToolInput.invalid creates invalid input with field and message', () {
      final input = ToolInput.invalid(
        toolId: 'memory_tool',
        rawParams: {'memoryContext': ''},
        field: 'memoryContext',
        message: 'Memory context cannot be empty',
      );
      expect(input.toolId, equals('memory_tool'));
      expect(input.isValid, isFalse);
      expect(input.source, equals('user'));
    });

    test('ToolInput.invalid has single field and message (not issues list)', () {
      final input = ToolInput.invalid(
        toolId: 'screen_tool',
        rawParams: {'brightness': -1},
        field: 'brightness',
        message: 'Must be between 0 and 100',
      );
      // No issues list — single field/message
      expect(input.validationField, equals('brightness'));
      expect(input.validationMessage, equals('Must be between 0 and 100'));
    });

    test('ToolInputValidationSeverity has error/warning/info only', () {
      expect(ToolInputValidationSeverity.error, isNotNull);
      expect(ToolInputValidationSeverity.warning, isNotNull);
      expect(ToolInputValidationSeverity.info, isNotNull);
      // NO critical
    });

    test('ToolInputValidationIssue structure', () {
      final issue = ToolInputValidationIssue(
        field: 'param1',
        message: 'invalid value',
        severity: ToolInputValidationSeverity.error,
      );
      expect(issue.field, equals('param1'));
      expect(issue.message, equals('invalid value'));
      expect(issue.severity, equals(ToolInputValidationSeverity.error));
    });

    test('ToolInput.withIssues factory adds validation issues', () {
      final issues = [
        ToolInputValidationIssue(
          field: 'action',
          message: 'required',
          severity: ToolInputValidationSeverity.error,
        ),
      ];
      final input = ToolInput.withIssues(
        toolId: 'nav_tool',
        params: {},
        issues: issues,
      );
      expect(input.isValid, isFalse);
    });

    test('ToolInput.errors getter returns only error-severity issues', () {
      final issues = [
        ToolInputValidationIssue(
          field: 'a',
          message: 'err',
          severity: ToolInputValidationSeverity.error,
        ),
        ToolInputValidationIssue(
          field: 'b',
          message: 'warn',
          severity: ToolInputValidationSeverity.warning,
        ),
      ];
      final input = ToolInput.withIssues(
        toolId: 'test_tool',
        params: {},
        issues: issues,
      );
      expect(input.errors.length, equals(1));
      expect(input.errors.first.field, equals('a'));
    });

    test('all factories require toolId', () {
      // ToolInput.valid requires toolId
      expect(
        () => ToolInput.valid(toolId: 't', params: {}),
        returnsNormally,
      );
      // ToolInput.invalid requires toolId
      expect(
        () => ToolInput.invalid(toolId: 't', rawParams: {}, field: 'f', message: 'm'),
        returnsNormally,
      );
    });
  });
}
