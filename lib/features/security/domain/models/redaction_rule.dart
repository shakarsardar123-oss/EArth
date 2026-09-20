/// redaction_rule.dart
/// AURA Assistant – Step 19: Security & Privacy Hardening
///
/// Redaction rule model — defines how a specific sensitive-data
/// category is detected and replaced.
///
/// FAIL CLOSED: when a pattern matches ambiguously, the rule
/// *over-redacts* rather than risk leaking sensitive data.
library;

import 'security_failure.dart';

/// Strategy for how matched content is replaced.
enum RedactionStrategy {
  /// Replace entire match with a fixed placeholder.
  /// e.g. "sk-abc123" → "[API_KEY_REDACTED]"
  fullPlaceholder,

  /// Keep first/last characters visible, redact middle.
  /// e.g. "sk-abc123def" → "sk-ab…[REDACTED]…ef"
  partialMask,

  /// Replace with a hash of the original (for audit correlation).
  hashedPlaceholder,

  /// Replace with category name only (least info).
  /// e.g. "password123" → "[REDACTED]"
  categoryOnly,
}

/// A single redaction rule that maps a sensitive-data category
/// to a detection pattern and replacement strategy.
class RedactionRule {
  /// The sensitive-data category this rule handles.
  final SensitiveDataCategory category;

  /// Regular expression pattern for detecting this category.
  /// Uses Dart RegExp syntax.
  final RegExp pattern;

  /// How detected matches are replaced in output.
  final RedactionStrategy strategy;

  /// The placeholder text used for [RedactionStrategy.fullPlaceholder]
  /// and [RedactionStrategy.categoryOnly].
  final String placeholder;

  /// Whether this rule is enabled (can be toggled by privacy config).
  final bool enabled;

  /// Priority — higher priority rules are applied first.
  /// Useful when patterns overlap (FAIL CLOSED: most restrictive wins).
  final int priority;

  const RedactionRule({
    required this.category,
    required this.pattern,
    this.strategy = RedactionStrategy.fullPlaceholder,
    this.placeholder = '[REDACTED]',
    this.enabled = true,
    this.priority = 0,
  });

  /// Apply this rule to [input] and return the redacted result.
  ///
  /// FAIL CLOSED: if the pattern match is ambiguous, the entire
  /// match is replaced (over-redacting is safe).
  String apply(String input) {
    if (!enabled) return input;

    return input.replaceAllMapped(pattern, (match) {
      switch (strategy) {
        case RedactionStrategy.fullPlaceholder:
          return placeholder;
        case RedactionStrategy.partialMask:
          return _partialMask(match.group(0)!);
        case RedactionStrategy.hashedPlaceholder:
          return _hashedPlaceholder(match.group(0)!);
        case RedactionStrategy.categoryOnly:
          return '[\${category.displayName.toUpperCase()}_REDACTED]';
      }
    });
  }

  /// Partial mask: show first 2 and last 2 chars, redact the rest.
  String _partialMask(String original) {
    if (original.length <= 4) return placeholder;
    final first = original.substring(0, 2);
    final last = original.substring(original.length - 2);
    return '\$first…[\${category.displayName.toUpperCase()}]…\$last';
  }

  /// Hashed placeholder — deterministic hash for audit correlation.
  /// Uses simple hashCode (never exposes original data).
  String _hashedPlaceholder(String original) {
    final hash = original.hashCode.abs().toRadixString(16);
    return '[\${category.displayName}:\$hash]';
  }

  /// Create a copy with optional overrides.
  RedactionRule copyWith({
    SensitiveDataCategory? category,
    RegExp? pattern,
    RedactionStrategy? strategy,
    String? placeholder,
    bool? enabled,
    int? priority,
  }) =>
      RedactionRule(
        category: category ?? this.category,
        pattern: pattern ?? this.pattern,
        strategy: strategy ?? this.strategy,
        placeholder: placeholder ?? this.placeholder,
        enabled: enabled ?? this.enabled,
        priority: priority ?? this.priority,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RedactionRule &&
          category == other.category &&
          strategy == other.strategy &&
          placeholder == other.placeholder &&
          enabled == other.enabled &&
          priority == other.priority;

  @override
  int get hashCode => Object.hash(category, strategy, placeholder, enabled, priority);

  @override
  String toString() =>
      'RedactionRule(category: \${category.name}, strategy: \$strategy, '
      'enabled: \$enabled, priority: \$priority)';
}

/// Default set of redaction rules for all built-in sensitive categories.
///
/// These are the *conservative* defaults — FAIL CLOSED means we err
/// on over-detection rather than under-detection.
class DefaultRedactionRules {
  DefaultRedactionRules._();

  /// All default redaction rules, sorted by priority (highest first).
  static List<RedactionRule> get all => [
    // ── Passwords (highest priority) ─────────────────────────────────
    RedactionRule(
      category: SensitiveDataCategory.password,
      pattern: RegExp(
        r'(password|passwd|pwd|pass_phrase|secret_key)\s*[:=]\s*\S+',
        caseSensitive: false,
      ),
      strategy: RedactionStrategy.categoryOnly,
      priority: 100,
    ),
    // ── API Keys ────────────────────────────────────────────────────
    RedactionRule(
      category: SensitiveDataCategory.apiKey,
      pattern: RegExp(
        r'(api_key|apikey|api[-_]?secret|token)\s*[:=]\s*\S+',
        caseSensitive: false,
      ),
      strategy: RedactionStrategy.fullPlaceholder,
      placeholder: '[API_KEY_REDACTED]',
      priority: 90,
    ),
    // ── Auth Tokens ──────────────────────────────────────────────────
    RedactionRule(
      category: SensitiveDataCategory.authToken,
      pattern: RegExp(
        r'(bearer\s+\S+|jwt\s*[:=]\s*\S+|access_token\s*[:=]\s*\S+|refresh_token\s*[:=]\s*\S+|id_token\s*[:=]\s*\S+)',
        caseSensitive: false,
      ),
      strategy: RedactionStrategy.fullPlaceholder,
      placeholder: '[AUTH_TOKEN_REDACTED]',
      priority: 85,
    ),
    // ── Private Keys ─────────────────────────────────────────────────
    RedactionRule(
      category: SensitiveDataCategory.privateKey,
      pattern: RegExp(
        r'-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----',
      ),
      strategy: RedactionStrategy.fullPlaceholder,
      placeholder: '[PRIVATE_KEY_REDACTED]',
      priority: 95,
    ),
    // ── Connection Strings ───────────────────────────────────────────
    RedactionRule(
      category: SensitiveDataCategory.connectionString,
      pattern: RegExp(
        r'(mongodb|postgres|mysql|redis|amqp)://\S+',
        caseSensitive: false,
      ),
      strategy: RedactionStrategy.hashedPlaceholder,
      priority: 80,
    ),
    // ── Credit Cards (Luhn-adjacent patterns) ────────────────────────
    RedactionRule(
      category: SensitiveDataCategory.creditCard,
      pattern: RegExp(
        r'\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b',
      ),
      strategy: RedactionStrategy.partialMask,
      placeholder: '[CC_REDACTED]',
      priority: 75,
    ),
    // ── National IDs (SSN-like patterns) ─────────────────────────────
    RedactionRule(
      category: SensitiveDataCategory.nationalId,
      pattern: RegExp(
        r'\b\d{3}-\d{2}-\d{4}\b',
      ),
      strategy: RedactionStrategy.fullPlaceholder,
      placeholder: '[NATIONAL_ID_REDACTED]',
      priority: 70,
    ),
    // ── Emails ──────────────────────────────────────────────────────
    RedactionRule(
      category: SensitiveDataCategory.email,
      pattern: RegExp(
        r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
      ),
      strategy: RedactionStrategy.partialMask,
      placeholder: '[EMAIL_REDACTED]',
      priority: 40,
    ),
    // ── Phone Numbers ───────────────────────────────────────────────
    RedactionRule(
      category: SensitiveDataCategory.phone,
      pattern: RegExp(
        r'(?:(?:\+?1[-. ]?)?(?:\(\d{3}\)|\d{3})[-. ]?\d{3}[-. ]?\d{4})|\+?\d{1,3}[-. ]?\d{3}[-. ]?\d{3}[-. ]?\d{3}',
      ),
      strategy: RedactionStrategy.partialMask,
      placeholder: '[PHONE_REDACTED]',
      priority: 35,
    ),
    // ── IP Addresses ─────────────────────────────────────────────────
    RedactionRule(
      category: SensitiveDataCategory.ipAddress,
      pattern: RegExp(
        r'\b(?:\d{1,3}\.){3}\d{1,3}\b',
      ),
      strategy: RedactionStrategy.hashedPlaceholder,
      priority: 30,
    ),
    // ── Biometric IDs ────────────────────────────────────────────────
    RedactionRule(
      category: SensitiveDataCategory.biometricId,
      pattern: RegExp(
        r'(biometric|fingerprint|face_id|touch_id|iris_scan)\s*[:=]\s*\S+',
        caseSensitive: false,
      ),
      strategy: RedactionStrategy.categoryOnly,
      priority: 60,
    ),
    // ── Medical Records ──────────────────────────────────────────────
    RedactionRule(
      category: SensitiveDataCategory.medicalRecord,
      pattern: RegExp(
        r'(diagnosis|icd[-_]?\d|medical_record|patient_id|mrn)\s*[:=]\s*\S+',
        caseSensitive: false,
      ),
      strategy: RedactionStrategy.categoryOnly,
      priority: 55,
    ),
    // ── Financial Account Numbers ────────────────────────────────────
    RedactionRule(
      category: SensitiveDataCategory.financialAccount,
      pattern: RegExp(
        r'(account_number|iban|routing_number|swift)\s*[:=]\s*\S+',
        caseSensitive: false,
      ),
      strategy: RedactionStrategy.fullPlaceholder,
      placeholder: '[FINANCIAL_REDACTED]',
      priority: 50,
    ),
    // ── Date of Birth ───────────────────────────────────────────────
    RedactionRule(
      category: SensitiveDataCategory.dateOfBirth,
      pattern: RegExp(
        r'(dob|date_of_birth|birth_date|birthday)\s*[:=]\s*\S+',
        caseSensitive: false,
      ),
      strategy: RedactionStrategy.fullPlaceholder,
      placeholder: '[DOB_REDACTED]',
      priority: 25,
    ),
    // ── Physical Addresses ──────────────────────────────────────────
    RedactionRule(
      category: SensitiveDataCategory.address,
      pattern: RegExp(
        r'(home_address|street_address|mailing_address|residence)\s*[:=]\s*\S+',
        caseSensitive: false,
      ),
      strategy: RedactionStrategy.fullPlaceholder,
      placeholder: '[ADDRESS_REDACTED]',
      priority: 20,
    ),
  ];
}
