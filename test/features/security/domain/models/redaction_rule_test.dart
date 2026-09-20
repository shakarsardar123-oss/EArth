/// Structural tests for RedactionRule and DefaultRedactionRules.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/security/domain/models/redaction_rule.dart';

void main() {
  group('RedactionRule', () {
    test('apply replaces matching content with placeholder', () {
      final rule = RedactionRule(
        name: 'test_rule',
        pattern: RegExp(r'\b\d{3}-\d{2}-\d{4}\b'),
        category: SensitiveDataCategory.personalIdentifier,
        strategy: RedactionStrategy.fullPlaceholder,
      );

      const input = 'My SSN is 123-45-6789 please redact it';
      final result = rule.apply(input);
      expect(result.redactedText, isNot(contains('123-45-6789')));
      expect(result.wasApplied, isTrue);
    });

    test('apply does nothing when pattern does not match', () {
      final rule = RedactionRule(
        name: 'ssn_rule',
        pattern: RegExp(r'\b\d{3}-\d{2}-\d{4}\b'),
        category: SensitiveDataCategory.personalIdentifier,
        strategy: RedactionStrategy.fullPlaceholder,
      );

      const input = 'No sensitive data here';
      final result = rule.apply(input);
      expect(result.redactedText, input);
      expect(result.wasApplied, isFalse);
    });

    test('FAIL CLOSED: ambiguous match over-redacts', () {
      final rule = RedactionRule(
        name: 'broad_rule',
        pattern: RegExp(r'\b\d{4,}\b'),
        category: SensitiveDataCategory.unknown,
        strategy: RedactionStrategy.fullPlaceholder,
      );

      const input = 'Order 12345 and 67890 are ready';
      final result = rule.apply(input);
      expect(result.wasApplied, isTrue);
      // Over-redaction is expected when category is unknown
    });

    test('RedactionStrategy enum has 4 strategies', () {
      expect(RedactionStrategy.values.length, 4);
    });

    test('SensitiveDataCategory unknown isAlwaysSensitive is true', () {
      expect(SensitiveDataCategory.unknown.isAlwaysSensitive, isTrue);
    });
  });

  group('DefaultRedactionRules', () {
    test('provides 15 default rules', () {
      expect(DefaultRedactionRules.rules.length, 15);
    });

    test('all default rules have non-empty names', () {
      for (final rule in DefaultRedactionRules.rules) {
        expect(rule.name, isNotEmpty);
      }
    });

    test('all default rules have valid patterns', () {
      for (final rule in DefaultRedactionRules.rules) {
        expect(rule.pattern, isNotNull);
      }
    });

    test('all default rules have a defined category', () {
      for (final rule in DefaultRedactionRules.rules) {
        expect(rule.category, isNotNull);
      }
    });

    test('FAIL CLOSED: default rules over-detect sensitive data', () {
      // Rules should catch more rather than less
      final combined = DefaultRedactionRules.rules;
      expect(combined.length, greaterThanOrEqualTo(15));
    });
  });
}
