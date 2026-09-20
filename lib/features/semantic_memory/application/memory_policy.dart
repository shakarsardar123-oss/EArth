/// memory_policy.dart
/// AURA Assistant – Step 17: Semantic Memory
///
/// Privacy policy for semantic memory content.
/// Rejects passwords, API keys, auth tokens, credentials,
/// and other sensitive information from being persisted.
/// Local-first, privacy-conscious.
library;

/// Result of a privacy policy check.
class PolicyCheckResult {
  /// Whether the content is allowed to be stored.
  final bool allowed;

  /// If rejected, the reason for rejection.
  final String? reason;

  const PolicyCheckResult({
    required this.allowed,
    this.reason,
  });
}

/// Privacy policy for semantic memory.
///
/// Scans content before storage and rejects entries that contain
/// sensitive information such as:
/// - Passwords and passphrases
/// - API keys and secrets
/// - Auth tokens (JWT, Bearer, OAuth)
/// - Credit card numbers
/// - Social security / national ID numbers
/// - Credentials in URL format (user:pass@host)
///
/// This is a heuristic check — it may have false positives or
/// false negatives. The goal is to be conservative: prefer
/// rejecting borderline content over leaking secrets.
class MemoryPolicy {
  // ─── Pattern definitions ─────────────────────────────────────────

  /// Regex patterns for sensitive content detection.
  /// Each pattern has a human-readable label for the rejection reason.
  static const Map<String, String> _sensitivePatterns = {
    // Passwords: common patterns
    r'(?i)password': 'Contains password reference',
    r'(?i)passphrase': 'Contains passphrase reference',
    r'(?i)pwd\s*[:=]': 'Contains password assignment',

    // API keys and secrets
    r'(?i)api[_\s]?key': 'Contains API key reference',
    r'(?i)secret[_\s]?key': 'Contains secret key reference',
    r'(?i)access[_\s]?key': 'Contains access key reference',
    r'(?i)private[_\s]?key': 'Contains private key reference',

    // Auth tokens
    r'(?i)auth[_\s]?token': 'Contains auth token reference',
    r'(?i)bearer\s+': 'Contains bearer token',
    r'(?i)jwt': 'Contains JWT reference',
    r'(?i)oauth': 'Contains OAuth reference',
    r'(?i)refresh[_\s]?token': 'Contains refresh token reference',

    // Credentials in URLs
    r'://[^\s]+:[^\s]+@': 'Contains credentials in URL',

    // Credit card numbers (basic Luhn-style pattern)
    r'\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b':
        'Contains possible credit card number',

    // SSN / national ID patterns
    r'\b\d{3}-\d{2}-\d{4}\b': 'Contains possible SSN',

    // Long hex strings (potential tokens/keys)
    r'\b[0-9a-fA-F]{32,}\b': 'Contains possible secret hex string',

    // Base64-encoded strings of significant length
    r'\b[A-Za-z0-9+/]{40,}={0,2}\b':
        'Contains possible encoded credential',
  };

  /// Content prefixes that indicate the user is sharing sensitive info.
  static const List<String> _sensitivePrefixes = [
    'my password is',
    'my passcode is',
    'my pin is',
    'my api key is',
    'my secret is',
    'my token is',
    'my credit card',
    'my social security',
    'my ssn is',
  ];

  /// Check whether [content] is allowed to be stored in semantic memory.
  ///
  /// Returns a [PolicyCheckResult] with [allowed] = true if the content
  /// passes all checks, or [allowed] = false with a [reason] if rejected.
  PolicyCheckResult check(String content) {
    if (content.trim().isEmpty) {
      return const PolicyCheckResult(
        allowed: false,
        reason: 'Empty content',
      );
    }

    final lowerContent = content.toLowerCase();

    // Check sensitive prefixes.
    for (final prefix in _sensitivePrefixes) {
      if (lowerContent.contains(prefix)) {
        return PolicyCheckResult(
          allowed: false,
          reason: 'Content appears to contain sensitive information: $prefix',
        );
      }
    }

    // Check regex patterns.
    for (final entry in _sensitivePatterns.entries) {
      try {
        final regex = RegExp(entry.key);
        if (regex.hasMatch(content)) {
          return PolicyCheckResult(
            allowed: false,
            reason: entry.value,
          );
        }
      } catch (_) {
        // Regex compilation failed – skip this pattern (defensive).
        continue;
      }
    }

    // All checks passed.
    return const PolicyCheckResult(allowed: true);
  }

  /// Check content and return a simple boolean.
  bool isAllowed(String content) => check(content).allowed;
}
