/// tool_input_test.dart
/// AURA Assistant – Step 22: Tests for ToolInput
///
/// Structural validation only (no Flutter/Dart SDK).
/// Tests: valid/invalid factory constructors, validation issues,
/// sanitization tracking, typed access.
library;

import 'package:test/test.dart';
import 'package:aura_assistant/features/tool_execution/tool_execution.dart';

void main() {
  group('ToolInput', () {
    test('.valid() creates input with isValid=true', () {
      final input = ToolInput.valid(
        rawParams: {'key': 'value'},
        sanitizedParams: {'key': 'value'},
      );
      expect(input.isValid, isTrue);
      expect(input.validationIssues, isEmpty);
      expect(input.wasSanitized, isFalse);
    });

    test('.invalid() creates input with isValid=false', () {
      final input = ToolInput.invalid(
        rawParams: {'key': '<script>'},
        validationIssues: [
          ToolInputValidationIssue(
            field: 'key',
            message: 'Injection detected',
            severity: ToolInputValidationSeverity.critical,
          ),
        ],
      );
      expect(input.isValid, isFalse);
      expect(input.validationIssues.length, equals(1));
    });

    test('sanitized input tracks wasSanitized=true', () {
      final input = ToolInput.valid(
        rawParams: {'key': '<script>alert(1)</script>'},
        sanitizedParams: {'key': 'alert(1)'},
        wasSanitized: true,
      );
      expect(input.wasSanitized, isTrue);
      expect(input.isValid, isTrue);
    });

    test('validation issue severity levels work', () {
      final warning = ToolInputValidationIssue(
        field: 'name',
        message: 'Long string',
        severity: ToolInputValidationSeverity.warning,
      );
      final critical = ToolInputValidationIssue(
        field: 'data',
        message: 'SQL injection',
        severity: ToolInputValidationSeverity.critical,
      );
      expect(warning.severity, equals(ToolInputValidationSeverity.warning));
      expect(critical.severity, equals(ToolInputValidationSeverity.critical));
    });

    test('getTyped returns typed value when present', () {
      final input = ToolInput.valid(
        rawParams: {'count': 42, 'name': 'test'},
        sanitizedParams: {'count': 42, 'name': 'test'},
      );
      expect(input.getTyped<int>('count'), equals(42));
      expect(input.getTyped<String>('name'), equals('test'));
    });

    test('getTyped returns null for missing key', () {
      final input = ToolInput.valid(
        rawParams: {},
        sanitizedParams: {},
      );
      expect(input.getTyped<int>('missing'), isNull);
    });

    test('source tracks where input came from', () {
      final input = ToolInput.valid(
        rawParams: {},
        sanitizedParams: {},
        source: 'voice',
      );
      expect(input.source, equals('voice'));
    });
  });
}
