/// default_sensitive_data_redactor.dart
/// AURA Assistant – Step 19: Security & Privacy Hardening
///
/// Default infrastructure implementation of SensitiveDataRedactor.
/// Uses DefaultRedactionRules and supports custom rule overrides.
///
/// FAIL CLOSED: on redaction error, over-redacts (full placeholder).
library;

import 'package:texo/core/errors/result.dart';
import '../domain/models/redaction_rule.dart';
import '../domain/models/security_failure.dart';
import '../domain/services/sensitive_data_redactor.dart';

class DefaultSensitiveDataRedactor implements SensitiveDataRedactor {
  final List<RedactionRule> _rules;

  DefaultSensitiveDataRedactor({
    List<RedactionRule>? customRules,
  }) : _rules = _buildRules(customRules);

  static List<RedactionRule> _buildRules(List<RedactionRule>? custom) {
    final base = List<RedactionRule>.from(DefaultRedactionRules.all);
    if (custom != null && custom.isNotEmpty) {
      base.addAll(custom);
    }
    // Sort by priority (higher priority first)
    base.sort((a, b) => b.priority.compareTo(a.priority));
    return base;
  }

  @override
  List<RedactionRule> get activeRules => List.unmodifiable(_rules);

  @override
  List<RedactionRule> get defaultRules =>
      List.unmodifiable(DefaultRedactionRules.all);

  @override
  Future<SecurityResult<RedactionResult>> redact(
    String content, {
    List<SensitiveDataCategory>? onlyCategories,
  }) async {
    try {
      if (content.isEmpty) {
        return Success(RedactionResult(
          redactedContent: content,
          redactionCount: 0,
          redactedCategories: [],
          wasOverRedacted: false,
        ));
      }

      String result = content;
      int appliedCount = 0;
      bool overRedacted = false;
      final List<SensitiveDataCategory> appliedCategories = [];

      for (final rule in _rules) {
        if (!rule.enabled) continue;
        // Filter by onlyCategories if provided
        if (onlyCategories != null &&
            !onlyCategories.contains(rule.category)) {
          continue;
        }

        for (final match in rule.pattern.allMatches(result)) {
          final replacement = rule.apply(
            result.substring(match.start, match.end),
          );

          result = result.replaceRange(
            match.start,
            match.end,
            replacement,
          );
          appliedCount++;

          if (!appliedCategories.contains(rule.category)) {
            appliedCategories.add(rule.category);
          }

          // Track over-redaction (full placeholder used when partial was
          // requested but string was too short)
          if (rule.strategy == RedactionStrategy.partialMask &&
              replacement == rule.placeholder) {
            overRedacted = true;
          }

          // After replacement, restart matching since positions shifted
          break;
        }
      }

      return Success(RedactionResult(
        redactedContent: result,
        redactionCount: appliedCount,
        redactedCategories: appliedCategories,
        wasOverRedacted: overRedacted,
      ));
    } catch (e) {
      // FAIL CLOSED: on error, over-redact to full placeholder
      return Success(const RedactionResult(
        redactedContent: '[CONTENT REDACTED: ERROR]',
        redactionCount: 1,
        redactedCategories: [SensitiveDataCategory.unknown],
        wasOverRedacted: true,
      ));
    }
  }

  @override
  String redactValue(String value, SensitiveDataCategory category) {
    try {
      final matchingRules = _rules
          .where((r) => r.category == category && r.enabled)
          .toList();

      if (matchingRules.isEmpty) {
        // FAIL CLOSED: no matching rule → full redaction
        return '[${category.name}]';
      }

      // Apply highest priority rule
      final rule = matchingRules.first;
      final redacted = rule.apply(value);

      // FAIL CLOSED: if the detection pattern doesn't match the raw value
      // (e.g. a bare API key without a key=value prefix), the value must
      // still be redacted because the caller already knows the category.
      if (redacted == value) {
        switch (rule.strategy) {
          case RedactionStrategy.fullPlaceholder:
            return rule.placeholder;
          case RedactionStrategy.partialMask:
            if (value.length <= 4) return rule.placeholder;
            final first = value.substring(0, 2);
            final last = value.substring(value.length - 2);
            return '$first…[${rule.category.displayName.toUpperCase()}]$last';
          case RedactionStrategy.hashedPlaceholder:
            final hash = value.hashCode.abs().toRadixString(16);
            return '[${rule.category.displayName}:$hash]';
          case RedactionStrategy.categoryOnly:
            return '[${rule.category.displayName.toUpperCase()}_REDACTED]';
        }
      }
      return redacted;
    } catch (_) {
      // FAIL CLOSED: on error, fully redact
      return '[${category.name}]';
    }
  }

  @override
  bool addCustomRule(RedactionRule rule) {
    try {
      // Check for duplicate category
      if (_rules.any((r) => r.category == rule.category)) {
        return false;
      }
      // Insert at correct priority position
      int insertIndex = _rules.indexWhere((r) => r.priority < rule.priority);
      if (insertIndex == -1) insertIndex = _rules.length;
      _rules.insert(insertIndex, rule);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  bool removeCustomRule(SensitiveDataCategory category) {
    try {
      // Can only remove non-default (custom) rules
      final defaultCategories =
          DefaultRedactionRules.all.map((r) => r.category).toSet();
      if (defaultCategories.contains(category)) {
        return false;
      }
      final initialLength = _rules.length;
      _rules.removeWhere((r) => r.category == category);
      return _rules.length < initialLength;
    } catch (_) {
      return false;
    }
  }
}
