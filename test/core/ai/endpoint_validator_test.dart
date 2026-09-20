import 'package:flutter_test/flutter_test.dart';

import 'package:aura_assistant/core/ai/endpoint_validator.dart';
import 'package:aura_assistant/features/security/domain/models/security_failure.dart';

void main() {
  // ─── validate() ─────────────────────────────────────────────────────

  group('EndpointValidator — validate()', () {
    test('accepts valid HTTPS URL with path', () {
      final result = EndpointValidator.validate('https://api.openai.com/v1');
      expect(result.isSuccess, isTrue);
      result.when(
        success: (v) => expect(v, 'https://api.openai.com/v1'),
        failure: (_) => fail('Expected success'),
      );
    });

    test('accepts valid HTTPS URL without path', () {
      final result = EndpointValidator.validate('https://api.openai.com');
      expect(result.isSuccess, isTrue);
      result.when(
        success: (v) => expect(v, 'https://api.openai.com'),
        failure: (_) => fail('Expected success'),
      );
    });

    test('accepts valid custom HTTPS URL (not OpenAI domain)', () {
      final result = EndpointValidator.validate('https://my-custom-llm.example.com/v1');
      expect(result.isSuccess, isTrue);
      result.when(
        success: (v) => expect(v, 'https://my-custom-llm.example.com/v1'),
        failure: (_) => fail('Expected success'),
      );
    });

    test('accepts HTTPS URL with port number', () {
      final result = EndpointValidator.validate('https://localhost:8443/v1');
      expect(result.isSuccess, isTrue);
      result.when(
        success: (v) => expect(v, 'https://localhost:8443/v1'),
        failure: (_) => fail('Expected success'),
      );
    });

    test('rejects HTTP scheme', () {
      final result = EndpointValidator.validate('http://api.openai.com/v1');
      expect(result.isFailure, isTrue);
      result.when(
        success: (_) => fail('Expected failure'),
        failure: (f) {
          expect(f, isA<SecurityFailure>());
          expect(f.phase, SecurityFailurePhase.providerPrivacy);
          expect(f.verdictReason, contains('Insecure scheme'));
          expect(f.verdictReason, contains('http'));
        },
      );
    });

    test('rejects FTP scheme', () {
      final result = EndpointValidator.validate('ftp://files.example.com');
      expect(result.isFailure, isTrue);
      result.when(
        success: (_) => fail('Expected failure'),
        failure: (f) {
          expect(f.verdictReason, contains('Insecure scheme'));
          expect(f.verdictReason, contains('ftp'));
        },
      );
    });

    test('rejects empty string', () {
      final result = EndpointValidator.validate('');
      expect(result.isFailure, isTrue);
      result.when(
        success: (_) => fail('Expected failure'),
        failure: (f) {
          expect(f.verdictReason, contains('must not be empty'));
        },
      );
    });

    test('rejects whitespace-only string', () {
      final result = EndpointValidator.validate('   ');
      expect(result.isFailure, isTrue);
      result.when(
        success: (_) => fail('Expected failure'),
        failure: (f) {
          expect(f.verdictReason, contains('must not be empty'));
        },
      );
    });

    test('rejects malformed URL (no scheme)', () {
      final result = EndpointValidator.validate('not-a-url');
      // Uri.parse may succeed with empty scheme, or it may still fail
      // depending on Dart version. Both outcomes are failures for us
      // (no HTTPS scheme).
      expect(result.isFailure, isTrue);
    });

    test('rejects URL with no host', () {
      final result = EndpointValidator.validate('https:///v1');
      expect(result.isFailure, isTrue);
      result.when(
        success: (_) => fail('Expected failure'),
        failure: (f) {
          expect(f.verdictReason, contains('must include a host'));
        },
      );
    });

    test('rejects URL with embedded credentials (userinfo)', () {
      final result = EndpointValidator.validate('https://user:pass@api.openai.com/v1');
      expect(result.isFailure, isTrue);
      result.when(
        success: (_) => fail('Expected failure'),
        failure: (f) {
          expect(f.verdictReason, contains('embedded credentials'));
        },
      );
    });

    test('does NOT restrict to OpenAI domains only', () {
      final result = EndpointValidator.validate('https://any-domain.io/api');
      expect(result.isSuccess, isTrue);
    });

    test('does NOT silently rewrite http:// to https://', () {
      final result = EndpointValidator.validate('http://api.openai.com/v1');
      // Must fail, not auto-rewrite to https
      expect(result.isFailure, isTrue);
    });

    test('trims whitespace before validation', () {
      final result = EndpointValidator.validate('  https://api.openai.com/v1  ');
      expect(result.isSuccess, isTrue);
      result.when(
        success: (v) => expect(v, 'https://api.openai.com/v1'),
        failure: (_) => fail('Expected success'),
      );
    });
  });

  // ─── normalizeTrailingSlash() ────────────────────────────────────────

  group('EndpointValidator — normalizeTrailingSlash()', () {
    test('strips trailing slash from URL', () {
      expect(
        EndpointValidator.normalizeTrailingSlash('https://example.com/v1/'),
        'https://example.com/v1',
      );
    });

    test('returns URL unchanged when no trailing slash', () {
      expect(
        EndpointValidator.normalizeTrailingSlash('https://example.com/v1'),
        'https://example.com/v1',
      );
    });

    test('handles root URL with trailing slash', () {
      expect(
        EndpointValidator.normalizeTrailingSlash('https://example.com/'),
        'https://example.com',
      );
    });

    test('handles root URL without trailing slash', () {
      expect(
        EndpointValidator.normalizeTrailingSlash('https://example.com'),
        'https://example.com',
      );
    });

    test('concat after normalize produces correct chat/completions path', () {
      // Simulates: '$baseUrl/chat/completions'
      final cases = <String, String>{
        'https://example.com': 'https://example.com/chat/completions',
        'https://example.com/': 'https://example.com/chat/completions',
        'https://example.com/v1': 'https://example.com/v1/chat/completions',
        'https://example.com/v1/': 'https://example.com/v1/chat/completions',
      };
      cases.forEach((baseUrl, expected) {
        final normalized = EndpointValidator.normalizeTrailingSlash(baseUrl);
        final full = '$normalized/chat/completions';
        expect(full, expected, reason: 'baseUrl=$baseUrl');
      });
    });

    test('no double-slash artifacts after normalization', () {
      final normalized = EndpointValidator.normalizeTrailingSlash('https://example.com/v1/');
      final full = '$normalized/chat/completions';
      // Must NOT contain //
      expect(full.contains('//chat'), isFalse);
      // The only double-slash should be in 'https://'
      expect(full, 'https://example.com/v1/chat/completions');
    });
  });
}
