/// tool_input_validator_test.dart
/// AURA Assistant – Step 22: Tests for ToolInputValidator
///
/// Structural validation only (no Flutter/Dart SDK).
/// Tests: structural validation (type/required/range),
/// injection detection (SQL/XSS/command), sanitization,
/// fail-closed on unknown.
library;

import 'package:test/test.dart';
import 'package:aura_assistant/features/tool_execution/tool_execution.dart';

void main() {
  group('ToolInputValidator', () {
    late ToolInputValidator validator;

    setUp(() {
      validator = ToolInputValidator();
    });

    group('structural validation', () {
      test('valid input passes', () {
        final input = ToolInput(
          toolId: 'device',
          action: 'get_battery',
          params: {'level': 80},
        );
        final result = validator.validate(input);
        expect(result.isValid, isTrue);
        expect(result.errors, isEmpty);
      });

      test('missing required param fails', () {
        final input = ToolInput(
          toolId: 'device',
          action: 'set_brightness',
          params: {}, // missing 'level' param
          requiredParams: ['level'],
        );
        final result = validator.validate(input);
        expect(result.isValid, isFalse);
        expect(result.errors, isNotEmpty);
      });

      test('wrong param type fails', () {
        final input = ToolInput(
          toolId: 'device',
          action: 'set_brightness',
          params: {'level': 'not-a-number'},
          paramTypes: {'level': int},
        );
        final result = validator.validate(input);
        expect(result.isValid, isFalse);
      });

      test('out-of-range value fails', () {
        final input = ToolInput(
          toolId: 'device',
          action: 'set_brightness',
          params: {'level': 999},
          paramRanges: {'level': (0, 100)},
        );
        final result = validator.validate(input);
        expect(result.isValid, isFalse);
      });
    });

    group('injection detection', () {
      test('SQL injection is detected', () {
        final input = ToolInput(
          toolId: 'memory',
          action: 'search',
          params: {'query': "'; DROP TABLE memories; --"},
        );
        final result = validator.validate(input);
        expect(result.hasInjection, isTrue);
      });

      test('XSS injection is detected', () {
        final input = ToolInput(
          toolId: 'screen',
          action: 'show_text',
          params: {'text': '<script>alert("xss")</script>'},
        );
        final result = validator.validate(input);
        expect(result.hasInjection, isTrue);
      });

      test('command injection is detected', () {
        final input = ToolInput(
          toolId: 'system',
          action: 'run',
          params: {'command': 'rm -rf / && echo done'},
        );
        final result = validator.validate(input);
        expect(result.hasInjection, isTrue);
      });

      test('clean input passes injection check', () {
        final input = ToolInput(
          toolId: 'device',
          action: 'get_battery',
          params: {'nice_param': 'clean value'},
        );
        final result = validator.validate(input);
        expect(result.hasInjection, isFalse);
      });
    });

    group('sanitization', () {
      test('sanitize strips dangerous characters', () {
        final sanitized = validator.sanitize('<b>bold</b> & "quotes"');
        expect(sanitized, isNot(contains('<')));
        expect(sanitized, isNot(contains('>')));
      });

      test('sanitize preserves safe content', () {
        final sanitized = validator.sanitize('Hello World 123');
        expect(sanitized, equals('Hello World 123'));
      });
    });

    group('fail-closed', () {
      test('unknown tool ID fails validation', () {
        final input = ToolInput(
          toolId: 'totally_unknown_tool',
          action: 'whatever',
          params: {},
        );
        final result = validator.validate(input);
        expect(result.isValid, isFalse);
      });
    });
  });
}
