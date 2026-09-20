/// security_verdict.dart
///
/// Security policy for device actions: the verdict value object and the registry
/// of permanently prohibited behaviour.
///
/// RECOVERED in P1-RECOVERY step R2 from the behaviour pinned by
/// `test/features/device_integration/security_verdict_test.dart`.
///
/// The registry is deliberately a hard-coded denylist rather than configuration:
/// automated aiming / cheating assistance must not become switchable at runtime.
library;

import '../entities/device_action.dart';

/// Whether policy permits an action.
enum SecurityVerdictType {
  /// The action may proceed.
  allowed,

  /// The action is refused.
  denied,
}

/// The result of screening one action against policy.
class SecurityVerdict {
  const SecurityVerdict._({required this.type, this.reason, this.rule});

  /// The action is permitted, optionally with an explanatory [reason].
  factory SecurityVerdict.allowed([String? reason]) =>
      SecurityVerdict._(type: SecurityVerdictType.allowed, reason: reason);

  /// The action is refused. A [reason] is mandatory so the refusal can always
  /// be explained to the user, and [rule] names the policy that triggered it.
  factory SecurityVerdict.denied(String reason, {String? rule}) =>
      SecurityVerdict._(
        type: SecurityVerdictType.denied,
        reason: reason,
        rule: rule,
      );

  /// Allowed or denied.
  final SecurityVerdictType type;

  /// Why this verdict was reached.
  final String? reason;

  /// Identifier of the policy rule responsible for a denial.
  final String? rule;

  /// Whether the action may proceed.
  bool get isAllowed => type == SecurityVerdictType.allowed;

  /// Whether the action is refused.
  bool get isDenied => type == SecurityVerdictType.denied;

  @override
  bool operator ==(Object other) =>
      other is SecurityVerdict &&
      other.type == type &&
      other.reason == reason &&
      other.rule == rule;

  @override
  int get hashCode => Object.hash(type, reason, rule);

  @override
  String toString() => 'SecurityVerdict(${type.name}'
      '${reason != null ? ': $reason' : ''}'
      '${rule != null ? ' [rule: $rule]' : ''})';
}

/// The fixed denylist of actions and targets this app will never automate.
abstract final class ProhibitedActionsRegistry {
  /// Action names that are refused outright.
  static const Set<String> prohibitedActionTypes = {
    'auto_aim',
    'aimbot',
  };

  /// Substrings that make a target label unacceptable.
  static const Set<String> prohibitedTargetKeywords = {
    'aimbot',
    'cheat',
    'hack',
  };

  /// Screens [action] against the denylist.
  ///
  /// Matching is case-insensitive, and target labels are matched by substring so
  /// that decorated labels (for example `"Enable Aimbot Now"`) are still caught.
  static SecurityVerdict check(DeviceAction action) {
    final label = action.targetLabel;
    if (label != null) {
      final lower = label.toLowerCase();
      for (final keyword in prohibitedTargetKeywords) {
        if (lower.contains(keyword)) {
          return SecurityVerdict.denied(
            'Target "$label" matches prohibited keyword "$keyword".',
            rule: 'prohibited_target_keyword',
          );
        }
      }
    }

    final package = action.packageName;
    if (package != null) {
      final lower = package.toLowerCase();
      for (final keyword in prohibitedTargetKeywords) {
        if (lower.contains(keyword)) {
          return SecurityVerdict.denied(
            'Package "$package" matches prohibited keyword "$keyword".',
            rule: 'prohibited_target_keyword',
          );
        }
      }
    }

    return SecurityVerdict.allowed();
  }

  /// Whether [name] is a prohibited action name.
  static bool isProhibitedActionName(String name) {
    final normalized = name.toLowerCase().trim().replaceAll(RegExp(r'[\s-]+'), '_');
    return prohibitedActionTypes.contains(normalized);
  }
}
