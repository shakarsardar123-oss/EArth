// tool_input_validator_test.dart — Structural tests for ToolInputValidator
// validate() returns InputValidationResult; toToolInput() bridges to ToolInput.
// Structural validation only.

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/tool_execution/infrastructure/tool_input_validator.dart';
import 'package:aura_assistant/features/tool_execution/domain/models/tool_input.dart';

void main() {
  group('InputValidationResult', () {
    test('has isValid, errors, sanitizedParams, wasSanitized, hasInjection', () {
      final result = InputValidationResult(
        isValid: true,
        errors: [],
        sanitizedParams: {'key': 'value'},
        wasSanitized: false,
        hasInjection: false,
      );
      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
      expect(result.sanitizedParams, isNotNull);
      expect(result.wasSanitized, isFalse);
      expect(result.hasInjection, isFalse);
    });

    test('invalid result has errors', () {
      final result = InputValidationResult(
        isValid: false,
        errors: ['Field "action" is required'],
        sanitizedParams: {},
        wasSanitized: false,
        hasInjection: true,
      );
      expect(result.isValid, isFalse);
      expect(result.errors.length, equals(1));
      expect(result.hasInjection, isTrue);
    });
  });

  group('ToolInputValidator', () {
    test('validate returns InputValidationResult', () {
      final validator = ToolInputValidator();
      final result = validator.validate(
        toolId: 'device_tool',
        params: {'action': 'flashlight_on'},
      );
      expect(result, isA<InputValidationResult>());
    });

    test('toToolInput bridges valid result to ToolInput.valid', () {
      final result = InputValidationResult(
        isValid: true,
        errors: [],
        sanitizedParams: {'action': 'test'},
        wasSanitized: true,
        hasInjection: false,
      );
      final input = result.toToolInput(toolId: 'device_tool', source: 'user');
      expect(input, isA<ToolInput>());
      expect(input.isValid, isTrue);
      expect(input.wasSanitized, isTrue);
    });

    test('toToolInput bridges invalid result to ToolInput.invalid', () {
      final result = InputValidationResult(
        isValid: false,
        errors: ['Missing action'],
        sanitizedParams: {},
        wasSanitized: false,
        hasInjection: false,
      );
      final input = result.toToolInput(toolId: 'screen_tool', source: 'user');
      expect(input.isValid, isFalse);
    });

    test('injection detected returns hasInjection true', () {
      final validator = ToolInputValidator();
      final result = validator.validate(
        toolId: 'test_tool',
        params: {'query': '<script>alert(1)</script>'},
      );
      expect(result.hasInjection, isTrue);
      expect(result.isValid, isFalse); // FAIL-CLOSED: injection = invalid
    });
  });
}
