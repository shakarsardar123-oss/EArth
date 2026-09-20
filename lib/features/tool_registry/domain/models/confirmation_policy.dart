/// confirmation_policy.dart
/// AURA Assistant – Step 20: Tool Registry & Allowlist
///
/// Defines when user confirmation is required before a tool can execute.
/// FAIL CLOSED: if confirmation status is ambiguous, treat as 'always'.
library;

/// Policy governing whether user confirmation is required before
/// executing a tool.
///
/// The policy is evaluated in the Tool Execution Gate *after*
/// allowlist and security checks pass but *before* actual execution.
/// A tool that requires confirmation will NOT execute until the user
/// explicitly confirms.
///
/// FAIL CLOSED: when in doubt → always require confirmation.
enum ConfirmationPolicy {
  /// No confirmation needed — tool is non-sensitive and low-risk.
  /// Only applies to tools that cannot modify state, access sensitive
  /// data, or communicate externally.
  never,

  /// Confirmation required only when the tool accesses sensitive data
  /// categories (as defined by [SensitiveDataCategory] in Step 19)
  /// or when the tool's risk level is elevated.
  whenSensitive,

  /// Confirmation always required — even for routine invocations.
  /// Applied to system, communication, and unknown-category tools
  /// by default.
  always,

  /// Policy could not be determined. FAIL CLOSED → treat as [always].
  unknown,
}

/// Extension methods for [ConfirmationPolicy].
extension ConfirmationPolicyX on ConfirmationPolicy {
  /// Resolve the effective policy. FAIL CLOSED: [unknown] → [always].
  ConfirmationPolicy get effective =>
      this == ConfirmationPolicy.unknown ? ConfirmationPolicy.always : this;

  /// Whether this policy requires confirmation for the given conditions.
  ///
  /// [accessesSensitiveData] is true when the tool's
  /// [ToolDefinition.accessedCategories] contains any sensitive category
  /// per Step 19's [SensitiveDataCategory].
  bool requiresConfirmation({bool accessesSensitiveData = false}) {
    final resolved = effective;
    switch (resolved) {
      case ConfirmationPolicy.never:
        return false;
      case ConfirmationPolicy.whenSensitive:
        return accessesSensitiveData;
      case ConfirmationPolicy.always:
        return true;
      case ConfirmationPolicy.unknown:
        return true; // FAIL CLOSED
    }
  }

  /// Human-readable label (English, for logging).
  String get label => switch (this) {
        ConfirmationPolicy.never => 'Never',
        ConfirmationPolicy.whenSensitive => 'When Sensitive',
        ConfirmationPolicy.always => 'Always',
        ConfirmationPolicy.unknown => 'Unknown (→ Always)',
      };
}
