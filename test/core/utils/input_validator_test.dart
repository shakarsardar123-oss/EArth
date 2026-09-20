import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/core/utils/input_validator.dart';

void main() {
  group('InputValidator', () {
    group('validateNotEmpty', () {
      test('returns null for non-empty string', () {
        expect(InputValidator.validateNotEmpty('hello'), isNull);
      });

      test('returns error for null value', () {
        expect(InputValidator.validateNotEmpty(null), isNotNull);
      });

      test('returns error for empty string', () {
        expect(InputValidator.validateNotEmpty(''), isNotNull);
      });

      test('returns error for whitespace-only string', () {
        expect(InputValidator.validateNotEmpty('   '), isNotNull);
      });

      test('includes field name in error message', () {
        final error = InputValidator.validateNotEmpty(null, 'Name');
        expect(error, contains('Name'));
      });

      test('uses default field name when not provided', () {
        final error = InputValidator.validateNotEmpty(null);
        expect(error, contains('Field'));
      });
    });

    group('validateEmail', () {
      test('returns null for valid email', () {
        expect(InputValidator.validateEmail('user@example.com'), isNull);
      });

      test('returns null for email with subdomain', () {
        expect(InputValidator.validateEmail('user@sub.example.co.uk'), isNull);
      });

      test('returns error for null', () {
        expect(InputValidator.validateEmail(null), isNotNull);
      });

      test('returns error for empty string', () {
        expect(InputValidator.validateEmail(''), isNotNull);
      });

      test('returns error for string without @', () {
        expect(InputValidator.validateEmail('userexample.com'), isNotNull);
      });

      test('returns error for string without domain', () {
        expect(InputValidator.validateEmail('user@'), isNotNull);
      });

      test('returns error for string without TLD', () {
        expect(InputValidator.validateEmail('user@example'), isNotNull);
      });
    });

    group('validateMinLength', () {
      test('returns null for string meeting minimum length', () {
        expect(InputValidator.validateMinLength('abcdef', 5), isNull);
      });

      test('returns null for string exactly at minimum length', () {
        expect(InputValidator.validateMinLength('abcde', 5), isNull);
      });

      test('returns error for string shorter than minimum', () {
        expect(InputValidator.validateMinLength('abc', 5), isNotNull);
      });

      test('returns error for null', () {
        expect(InputValidator.validateMinLength(null, 3), isNotNull);
      });

      test('includes field name and min length in error', () {
        final error = InputValidator.validateMinLength('ab', 5, 'Password');
        expect(error, contains('Password'));
        expect(error, contains('5'));
      });

      test('uses default field name', () {
        final error = InputValidator.validateMinLength(null, 3);
        expect(error, contains('Field'));
      });
    });
  });
}
