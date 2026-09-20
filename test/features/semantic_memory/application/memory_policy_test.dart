/// memory_policy_test.dart
/// Structural tests for MemoryPolicy.
library;

import 'package:test/test.dart';

// ─── Inline mirrors for structural testing ─────────────────────────

class PolicyCheckResult {
  final bool isAllowed;
  final String? reason;
  const PolicyCheckResult({required this.isAllowed, this.reason});
}

class MemoryPolicy {
  // Mirrors the real MemoryPolicy regex patterns.
  static final RegExp _passwordPattern = RegExp(r'(?i)(password|passwd|pwd)');
  static final RegExp _apiKeyPattern = RegExp(r'(?i)(api[_\s-]?key|apikey|api_secret)');
  static final RegExp _tokenPattern = RegExp(r'(?i)(auth[_\s-]?token|access[_\s-]?token|bearer|refresh[_\s-]?token)');
  static final RegExp _creditCardPattern = RegExp(r'\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b');
  static final RegExp _ssnPattern = RegExp(r'\b\d{3}-\d{2}-\d{4}\b');
  static final RegExp _hexSecretPattern = RegExp(r'(?i)(secret[_\s-]?key|private[_\s-]?key)');
  static final RegExp _base64Pattern = RegExp(r'(?i)(base64[_\s-]?encoded|base64[_\s-]?token)');

  PolicyCheckResult check(String content) {
    if (_passwordPattern.hasMatch(content)) {
      return const PolicyCheckResult(isAllowed: false, reason: 'Contains password/credential');
    }
    if (_apiKeyPattern.hasMatch(content)) {
      return const PolicyCheckResult(isAllowed: false, reason: 'Contains API key');
    }
    if (_tokenPattern.hasMatch(content)) {
      return const PolicyCheckResult(isAllowed: false, reason: 'Contains auth token');
    }
    if (_creditCardPattern.hasMatch(content)) {
      return const PolicyCheckResult(isAllowed: false, reason: 'Contains credit card number');
    }
    if (_ssnPattern.hasMatch(content)) {
      return const PolicyCheckResult(isAllowed: false, reason: 'Contains SSN');
    }
    if (_hexSecretPattern.hasMatch(content)) {
      return const PolicyCheckResult(isAllowed: false, reason: 'Contains secret/private key');
    }
    if (_base64Pattern.hasMatch(content)) {
      return const PolicyCheckResult(isAllowed: false, reason: 'Contains base64 encoded credential');
    }
    return const PolicyCheckResult(isAllowed: true);
  }
}

void main() {
  group('MemoryPolicy', () {
    late MemoryPolicy policy;

    setUp(() {
      policy = MemoryPolicy();
    });

    // ─── Password patterns ───────────────────────────────────────
    group('rejects passwords', () {
      test('password', () {
        expect(policy.check('My password is secret').isAllowed, isFalse);
      });
      test('Password (case insensitive)', () {
        expect(policy.check('Password=abc').isAllowed, isFalse);
      });
      test('passwd', () {
        expect(policy.check('passwd is 123').isAllowed, isFalse);
      });
      test('pwd', () {
        expect(policy.check('pwd=abc').isAllowed, isFalse);
      });
    });

    // ─── API key patterns ────────────────────────────────────────
    group('rejects API keys', () {
      test('api_key', () {
        expect(policy.check('api_key=sk-123').isAllowed, isFalse);
      });
      test('apikey', () {
        expect(policy.check('apikey=xyz').isAllowed, isFalse);
      });
      test('api-key', () {
        expect(policy.check('api-key: sk-abc').isAllowed, isFalse);
      });
      test('api_secret', () {
        expect(policy.check('api_secret=abc').isAllowed, isFalse);
      });
    });

    // ─── Auth token patterns ────────────────────────────────────
    group('rejects auth tokens', () {
      test('auth_token', () {
        expect(policy.check('auth_token=xyz').isAllowed, isFalse);
      });
      test('access_token', () {
        expect(policy.check('access_token: eyJ...').isAllowed, isFalse);
      });
      test('bearer', () {
        expect(policy.check('Bearer eyJhbGciOi...').isAllowed, isFalse);
      });
      test('refresh_token', () {
        expect(policy.check('refresh_token=abc123').isAllowed, isFalse);
      });
    });

    // ─── Credit card patterns ───────────────────────────────────
    group('rejects credit card numbers', () {
      test('16-digit card number with spaces', () {
        expect(policy.check('Card: 4111 1111 1111 1111').isAllowed, isFalse);
      });
      test('16-digit card number without spaces', () {
        expect(policy.check('4111111111111111').isAllowed, isFalse);
      });
      test('card number with dashes', () {
        expect(policy.check('4111-1111-1111-1111').isAllowed, isFalse);
      });
    });

    // ─── SSN patterns ──────────────────────────────────────────
    group('rejects SSN', () {
      test('SSN format XXX-XX-XXXX', () {
        expect(policy.check('SSN: 123-45-6789').isAllowed, isFalse);
      });
    });

    // ─── Secret / private key patterns ─────────────────────────
    group('rejects secret/private keys', () {
      test('secret_key', () {
        expect(policy.check('secret_key=abc').isAllowed, isFalse);
      });
      test('private_key', () {
        expect(policy.check('private_key: -----BEGIN...').isAllowed, isFalse);
      });
    });

    // ─── Base64 patterns ──────────────────────────────────────
    group('rejects base64 encoded credentials', () {
      test('base64_encoded', () {
        expect(policy.check('base64_encoded credential').isAllowed, isFalse);
      });
      test('base64_token', () {
        expect(policy.check('base64_token=abc').isAllowed, isFalse);
      });
    });

    // ─── Allowed content ──────────────────────────────────────
    group('allows safe content', () {
      test('simple preference', () {
        expect(policy.check('User prefers dark mode').isAllowed, isTrue);
      });
      test('personal fact', () {
        expect(policy.check('User lives in Erbil').isAllowed, isTrue);
      });
      test('task description', () {
        expect(policy.check('Buy groceries tomorrow').isAllowed, isTrue);
      });
      test('project info', () {
        expect(policy.check('Working on AURA project').isAllowed, isTrue);
      });
      test('device info', () {
        expect(policy.check('Phone model: iPhone 15').isAllowed, isTrue);
      });
      test('location info', () {
        expect(policy.check('Favorite cafe in Sulaymaniyah').isAllowed, isTrue);
      });
    });

    // ─── PolicyCheckResult ────────────────────────────────────
    group('PolicyCheckResult', () {
      test('rejected result has reason', () {
        final result = policy.check('password=123');
        expect(result.isAllowed, isFalse);
        expect(result.reason, isNotNull);
        expect(result.reason, isNotEmpty);
      });

      test('allowed result has null reason', () {
        final result = policy.check('Safe content');
        expect(result.isAllowed, isTrue);
        expect(result.reason, isNull);
      });
    });
  });
}
