/// security_failure.dart
/// AURA Assistant – Step 19: Security & Privacy Hardening
///
/// Failure type for all security operations.
/// Follows the project convention: phase enum + private constructor
/// + factory constructors per phase + private subtypes with mixins
/// + action/cause/message fields.
///
/// FAIL CLOSED: unknown failures are always treated as blocked/denied.
library;

import 'package:aura_assistant/core/errors/result.dart';

// ─── Phase enum ──────────────────────────────────────────────────────

/// Phase of a security operation where a failure occurred.
enum SecurityFailurePhase {
  /// Scanning content for secrets / sensitive data.
  scanning,

  /// Redacting sensitive data from output.
  redaction,

  /// Validating an agent or tool action.
  actionValidation,

  /// Checking memory privacy policy.
  memoryPrivacy,

  /// Checking permission-gated operation.
  permissionSecurity,

  /// Checking API provider privacy.
  providerPrivacy,

  /// Protecting screen/vision content.
  screenPrivacy,

  /// Protecting voice/audio content.
  voicePrivacy,

  /// Secure storage read/write.
  secureStorage,

  /// Applying security configuration.
  configApplication,

  /// Updating security state.
  stateUpdate,

  /// Auditing a security event.
  audit,

  /// Recovery from a previous security failure.
  recovery,

  /// Unknown / unexpected phase — FAIL CLOSED.
  unknown,
}

// ─── Mixins for carrying extra context ───────────────────────────────

/// Mixin for failures that carry an explicit *action* string
/// (e.g. the tool name or permission that was blocked).
mixin _ActionCarryingFailure {
  String get action;
}

/// Mixin for failures that carry an explicit *verdict* string
/// (e.g. the SecurityVerdict reason).
mixin _VerdictCarryingFailure {
  String get verdictReason;
}

/// Mixin for failures that carry a sensitive-data *category*.
mixin _CategoryCarryingFailure {
  SensitiveDataCategory get category;
}

// ─── SecurityFailure ──────────────────────────────────────────────────

/// Failure type for security & privacy hardening operations.
///
/// Each failure carries:
/// - [phase]: where in the security pipeline the failure happened.
/// - [message]: human-readable description.
/// - [action]: optional action/tool/permission that caused the failure.
/// - [cause]: optional underlying exception or error.
/// - [verdictReason]: optional SecurityVerdict reason (for action/permission failures).
/// - [category]: optional SensitiveDataCategory (for redaction/scanning failures).
///
/// FAIL CLOSED: any failure defaults to *blocked* — never default-allow.
class SecurityFailure {
  final SecurityFailurePhase phase;
  final String message;
  final String? action;
  final Object? cause;
  final String? verdictReason;
  final SensitiveDataCategory? category;

  const SecurityFailure._({
    required this.phase,
    required this.message,
    this.action,
    this.cause,
    this.verdictReason,
    this.category,
  });

  // ─── Factory constructors ────────────────────────────────────────

  /// Content scanning failed — sensitive data detected.
  factory SecurityFailure.sensitiveDataDetected({
    required SensitiveDataCategory category,
    String? action,
    Object? cause,
  }) =>
      SecurityFailure._(
        phase: SecurityFailurePhase.scanning,
        message: 'Sensitive data detected: \${category.name}',
        action: action,
        cause: cause,
        category: category,
      );

  /// Redaction failed — could not safely redact content.
  factory SecurityFailure.redactionFailed({
    required SensitiveDataCategory category,
    String? action,
    Object? cause,
  }) =>
      SecurityFailure._(
        phase: SecurityFailurePhase.redaction,
        message: 'Failed to redact sensitive data: \${category.name}',
        action: action,
        cause: cause,
        category: category,
      );

  /// Redaction over-applied (false positive) — acceptable under FAIL CLOSED.
  factory SecurityFailure.redactionOverApplied({
    String? action,
    Object? cause,
  }) =>
      SecurityFailure._(
        phase: SecurityFailurePhase.redaction,
        message: 'Redaction over-applied (safe false positive).',
        action: action,
        cause: cause,
      );

  /// Agent/tool action blocked by security policy.
  factory SecurityFailure.actionBlocked({
    required String action,
    required String verdictReason,
    Object? cause,
  }) =>
      SecurityFailure._(
        phase: SecurityFailurePhase.actionValidation,
        message: 'Action blocked: \$action',
        action: action,
        verdictReason: verdictReason,
        cause: cause,
      );

  /// Agent/tool action is unknown — blocked by FAIL CLOSED default.
  factory SecurityFailure.actionUnknown({
    required String action,
    Object? cause,
  }) =>
      SecurityFailure._(
        phase: SecurityFailurePhase.actionValidation,
        message: 'Unknown action blocked (fail-closed): \$action',
        action: action,
        verdictReason: 'Unknown action — default deny.',
        cause: cause,
      );

  /// Memory privacy check denied storage.
  factory SecurityFailure.memoryPrivacyDenied({
    required String action,
    required String verdictReason,
    Object? cause,
  }) =>
      SecurityFailure._(
        phase: SecurityFailurePhase.memoryPrivacy,
        message: 'Memory privacy denied: \$action',
        action: action,
        verdictReason: verdictReason,
        cause: cause,
      );

  /// Permission-gated operation denied.
  factory SecurityFailure.permissionDenied({
    required String action,
    required String verdictReason,
    Object? cause,
  }) =>
      SecurityFailure._(
        phase: SecurityFailurePhase.permissionSecurity,
        message: 'Permission denied for: \$action',
        action: action,
        verdictReason: verdictReason,
        cause: cause,
      );

  /// API provider privacy violation detected.
  factory SecurityFailure.providerPrivacyViolation({
    required String action,
    required String verdictReason,
    Object? cause,
  }) =>
      SecurityFailure._(
        phase: SecurityFailurePhase.providerPrivacy,
        message: 'Provider privacy violation: \$action',
        action: action,
        verdictReason: verdictReason,
        cause: cause,
      );

  /// Screen/vision privacy violation detected.
  factory SecurityFailure.screenPrivacyViolation({
    required String action,
    String? verdictReason,
    Object? cause,
  }) =>
      SecurityFailure._(
        phase: SecurityFailurePhase.screenPrivacy,
        message: 'Screen privacy violation: \$action',
        action: action,
        verdictReason: verdictReason,
        cause: cause,
      );

  /// Voice/audio privacy violation detected.
  factory SecurityFailure.voicePrivacyViolation({
    required String action,
    String? verdictReason,
    Object? cause,
  }) =>
      SecurityFailure._(
        phase: SecurityFailurePhase.voicePrivacy,
        message: 'Voice privacy violation: \$action',
        action: action,
        verdictReason: verdictReason,
        cause: cause,
      );

  /// Secure storage read/write failure.
  factory SecurityFailure.secureStorageFailed({
    required String action,
    Object? cause,
  }) =>
      SecurityFailure._(
        phase: SecurityFailurePhase.secureStorage,
        message: 'Secure storage operation failed: \$action',
        action: action,
        cause: cause,
      );

  /// Security configuration application failed.
  factory SecurityFailure.configApplicationFailed({
    required String action,
    Object? cause,
  }) =>
      SecurityFailure._(
        phase: SecurityFailurePhase.configApplication,
        message: 'Security config failed: \$action',
        action: action,
        cause: cause,
      );

  /// Security state update failed.
  factory SecurityFailure.stateUpdateFailed({
    required String action,
    Object? cause,
  }) =>
      SecurityFailure._(
        phase: SecurityFailurePhase.stateUpdate,
        message: 'Security state update failed: \$action',
        action: action,
        cause: cause,
      );

  /// Audit log write failed.
  factory SecurityFailure.auditFailed({
    required String action,
    Object? cause,
  }) =>
      SecurityFailure._(
        phase: SecurityFailurePhase.audit,
        message: 'Security audit failed: \$action',
        action: action,
        cause: cause,
      );

  /// Recovery from a previous security failure failed.
  factory SecurityFailure.recoveryFailed({
    required String action,
    Object? cause,
  }) =>
      SecurityFailure._(
        phase: SecurityFailurePhase.recovery,
        message: 'Security recovery failed: \$action',
        action: action,
        cause: cause,
      );

  /// Unknown / unexpected failure — FAIL CLOSED default.
  factory SecurityFailure.unknown({
    String? action,
    Object? cause,
    String? message,
  }) =>
      SecurityFailure._(
        phase: SecurityFailurePhase.unknown,
        message: message ?? 'Unknown security failure — default deny.',
        action: action,
        cause: cause,
        verdictReason: 'Unknown failure — fail-closed.',
      );

  // ─── Convenience ──────────────────────────────────────────────────

  /// Whether this failure represents a *blocked* action.
  /// Under FAIL CLOSED, all failures are considered blocked.
  bool get isBlocked => true;

  /// Wrap this failure as a [Result.failure].
  Result<T, SecurityFailure> asFailure<T>() => Result.failure(this);

  /// Detailed description for logging (never includes raw secrets).
  String get detail =>
      'SecurityFailure(phase: \$phase, action: \$action, '
      'verdict: \$verdictReason, category: \$category, '
      'message: \$message)';

  @override
  String toString() => detail;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SecurityFailure &&
          phase == other.phase &&
          message == other.message &&
          action == other.action &&
          verdictReason == other.verdictReason &&
          category == other.category;

  @override
  int get hashCode => Object.hash(
        phase,
        message,
        action,
        verdictReason,
        category,
      );
}

// ─── SensitiveDataCategory ────────────────────────────────────────────

/// Categories of sensitive data that the security layer detects
/// and redacts. Used in scanning, redaction, and audit operations.
///
/// FAIL CLOSED: [unknown] category is treated as sensitive.
enum SensitiveDataCategory {
  /// Passwords and passphrases.
  password,

  /// API keys, tokens, secrets.
  apiKey,

  /// OAuth tokens, bearer tokens, JWTs.
  authToken,

  /// Credit card numbers, CVV, expiry.
  creditCard,

  /// Social security / national ID numbers.
  nationalId,

  /// Email addresses (PII).
  email,

  /// Phone numbers (PII).
  phone,

  /// IP addresses (PII / network).
  ipAddress,

  /// Physical addresses (PII).
  address,

  /// Dates of birth (PII).
  dateOfBirth,

  /// Medical / health data (HIPAA-sensitive).
  medicalRecord,

  /// Financial account numbers.
  financialAccount,

  /// Biometric data identifiers.
  biometricId,

  /// Private keys (crypto / SSH / TLS).
  privateKey,

  /// Connection strings (DB URLs with embedded credentials).
  connectionString,

  /// Any content matching Step 17 MemoryPolicy sensitive patterns.
  memoryPolicySensitive,

  /// Unknown — FAIL CLOSED: treated as sensitive.
  unknown;

  /// Whether this category is always treated as sensitive
  /// (even in ambiguous cases).
  bool get isAlwaysSensitive => true;

  /// Human-readable display name (used in audit logs, never raw data).
  String get displayName => switch (this) {
        password => 'Password',
        apiKey => 'API Key',
        authToken => 'Auth Token',
        creditCard => 'Credit Card',
        nationalId => 'National ID',
        email => 'Email',
        phone => 'Phone Number',
        ipAddress => 'IP Address',
        address => 'Physical Address',
        dateOfBirth => 'Date of Birth',
        medicalRecord => 'Medical Record',
        financialAccount => 'Financial Account',
        biometricId => 'Biometric ID',
        privateKey => 'Private Key',
        connectionString => 'Connection String',
        memoryPolicySensitive => 'Memory Policy Sensitive',
        unknown => 'Unknown (Sensitive)',
      };
}

// ─── Result type alias ────────────────────────────────────────────────

/// Convenience type alias for security operations.
typedef SecurityResult<T> = Result<T, SecurityFailure>;
