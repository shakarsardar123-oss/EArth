/// redaction_rule_test.dart
/// Step 21 – REWRITTEN security regression tests for RedactionRule (Step 19)
///
/// ORIGINAL STEP 19 BUGS FIXED:
/// - Used `name` field → RedactionRule has no name field; use pattern/description
/// - Used `result.redactedText`/`result.wasApplied` → apply() returns String
/// - Used `DefaultRedactionRules.rules` → correct: DefaultRedactionRules.all
/// - Used `SensitiveDataCategory.unknown.isAlwaysSensitive` → ALL categories
///   have isAlwaysSensitive=true (unknown is NOT special)

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/security/domain/models/redaction_rule.dart';
import 'package:aura_assistant/features/security/domain/models/sensitive_data_category.dart';

void main() {
  group('RedactionRule', () {
    test('construction with pattern and description', () {
      // RedactionRule takes pattern + description (NOT name)
      final rule = RedactionRule(
        pattern: RegExp(r'\b\d{16}\b'),
        description: 'Credit card number',
        category: SensitiveDataCategory.financial,
      );
      expect(rule.pattern, isA<RegExp>());
      expect(rule.description, 'Credit card number');
      expect(rule.category, SensitiveDataCategory.financial);
    });

    test('apply() returns String (not an object with redactedText)', () {
      // CORRECTED: apply() returns String directly
      final rule = RedactionRule(
        pattern: RegExp(r'test'),
        description: 'Test rule',
        category: SensitiveDataCategory.personal,
      );
      final result = rule.apply('this is a test message');
      // apply() returns String, NOT an object with .redactedText/.wasApplied
      expect(result, isA<String>());
    });

    test('apply() redacts matching patterns', () {
      final rule = RedactionRule(
        pattern: RegExp(r'secret'),
        description: 'Secret word',
        category: SensitiveDataCategory.credential,
      );
      final redacted = rule.apply('my secret password');
      // The word "secret" should be replaced/redacted
      expect(redacted, isNot(contains('secret')));
    });

    test('apply() on non-matching text returns original', () {
      final rule = RedactionRule(
        pattern: RegExp(r'\b\d{16}\b'),
        description: 'Card number',
        category: SensitiveDataCategory.financial,
      );
      final result = rule.apply('no card numbers here');
      expect(result, 'no card numbers here');
    });
  });

  group('DefaultRedactionRules', () {
    test('.all returns list of rules (NOT .rules)', () {
      // CORRECTED: DefaultRedactionRules.all, not DefaultRedactionRules.rules
      final rules = DefaultRedactionRules.all;
      expect(rules, isA<List<RedactionRule>>());
      expect(rules.isNotEmpty, isTrue);
    });

    test('all default rules have valid patterns', () {
      for (final rule in DefaultRedactionRules.all) {
        expect(rule.pattern, isA<RegExp>());
        expect(rule.description, isNotEmpty);
        expect(rule.category, isNotNull);
      }
    });
  });

  group('SensitiveDataCategory', () {
    test('ALL categories have isAlwaysSensitive=true (including unknown)', () {
      // CORRECTD: original test assumed unknown.isAlwaysSensitive=false
      // WRONG: ALL SensitiveDataCategory values have isAlwaysSensitive=true
      for (final cat in SensitiveDataCategory.values) {
        expect(cat.isAlwaysSensitive, isTrue,
            reason: '${cat.name}.isAlwaysSensitive must be true (fail-closed)');
      }
    });

    test('values include personal, health, financial, credential, unknown', () {
      expect(SensitiveDataCategory.values.length, 5);
      expect(SensitiveDataCategory.values, contains(SensitiveDataCategory.personal));
      expect(SensitiveDataCategory.values, contains(SensitiveDataCategory.health));
      expect(SensitiveDataCategory.values, contains(SensitiveDataCategory.financial));
      expect(SensitiveDataCategory.values, contains(SensitiveDataCategory.credential));
      expect(SensitiveDataCategory.values, contains(SensitiveDataCategory.unknown));
    });

    // FAIL CLOSED: unknown category must still be treated as sensitive
    test('unknown category is fail-closed (isAlwaysSensitive=true)', () {
      expect(SensitiveDataCategory.unknown.isAlwaysSensitive, isTrue);
    });
  });
}
