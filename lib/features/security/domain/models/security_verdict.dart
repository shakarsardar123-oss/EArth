library;
import 'security_failure.dart' show SensitiveDataCategory;
/// security_verdict.dart
/// AURA Assistant – Step 19: Security & Privacy Hardening
///
/// Security verdict returned by all security checks.
/// FAIL CLOSED: the default is *deny*. Every operation must
/// explicitly receive an *allowed* verdict to proceed;
/// any ambiguity or missing data results in *denied*.
///
/// This is the security layer's equivalent of Step 16's
/// permission status — but broader, covering secrets,
/// redaction, agent actions, provider privacy, etc.

/// Security verdict returned by all security checks.
///
/// - [allowed]: the operation may proceed.
/// - [denied]: the operation is blocked (with a reason).
///
/// FAIL CLOSED: when in doubt, create a *denied* verdict.
/// NEVER default to *allowed*.
class SecurityVerdict {
  /// Whether the operation is allowed to proceed.
  final bool allowed;

  /// Human-readable reason (always present for *denied*,
  /// optional for *allowed*).
  final String? reason;

  /// The action or operation this verdict applies to.
  final String? action;

  /// The category of sensitive data involved (if applicable).
  final SensitiveDataCategory? category;

  /// Whether the verdict is a result of FAIL CLOSED (default deny).
  final bool failClosed;

  const SecurityVerdict._({
    required this.allowed,
    this.reason,
    this.action,
    this.category,
    this.failClosed = false,
  });

  // ─── Factory constructors ────────────────────────────────────────

  /// Explicitly allow the operation.
  factory SecurityVerdict.allowed({String? reason, String? action}) =>
      SecurityVerdict._(
        allowed: true,
        reason: reason ?? 'Operation allowed.',
        action: action,
      );

  /// Deny the operation with an explicit reason.
  factory SecurityVerdict.denied({
    required String reason,
    String? action,
    SensitiveDataCategory? category,
  }) =>
      SecurityVerdict._(
        allowed: false,
        reason: reason,
        action: action,
        category: category,
      );

  /// FAIL CLOSED verdict — deny because state is unknown/ambiguous.
  factory SecurityVerdict.failClosed({
    String? reason,
    String? action,
  }) =>
      SecurityVerdict._(
        allowed: false,
        reason: reason ?? 'Fail-closed: operation denied by default.',
        action: action,
        failClosed: true,
      );

  // ─── Getters ────────────────────────────────────────────────────

  /// Whether this is an explicit denial (not fail-closed).
  bool get isExplicitlyDenied => !allowed && !failClosed;

  /// Whether this is a fail-closed denial.
  bool get isFailClosedDenial => !allowed && failClosed;

  /// Convenience: whether the verdict is denied (any reason).
  bool get isDenied => !allowed;

  /// Redacted display string for logging — never includes raw secrets.
  String get displayReason =>
      allowed
          ? 'Allowed: \${reason ?? "no reason"}'
          : 'Denied: \${reason ?? "unspecified"}\${failClosed ? " (fail-closed)" : ""}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SecurityVerdict &&
          allowed == other.allowed &&
          reason == other.reason &&
          action == other.action &&
          category == other.category &&
          failClosed == other.failClosed;

  @override
  int get hashCode => Object.hash(allowed, reason, action, category, failClosed);

  @override
  String toString() =>
      'SecurityVerdict(allowed: \$allowed, reason: \$reason, '
      'action: \$action, failClosed: \$failClosed)';
}
