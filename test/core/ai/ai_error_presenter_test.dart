/// ai_error_presenter_test.dart
/// AURA Assistant – Phase 1: tests for the friendly, localized AI error
/// presenter. Pure + deterministic (no I/O, no network). Localized strings
/// are obtained synchronously via lookupS(en).
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:texo/core/ai/ai_error_presenter.dart';
import 'package:texo/core/ai/provider_exception.dart';
import 'package:texo/l10n/app_localizations.dart';

void main() {
  final l10n = lookupS(const Locale('en'));

  group('categorize – AIProviderException', () {
    test('NO_API_KEY code → missingKey', () {
      const e = AIProviderException(message: 'x', errorCode: 'NO_API_KEY');
      expect(AIErrorPresenter.categorize(e), AIErrorCategory.missingKey);
    });

    test('401/403 → auth', () {
      expect(
        AIErrorPresenter.categorize(
          const AIProviderException(message: 'x', statusCode: 401),
        ),
        AIErrorCategory.auth,
      );
      expect(
        AIErrorPresenter.categorize(
          const AIProviderException(message: 'x', statusCode: 403),
        ),
        AIErrorCategory.auth,
      );
    });

    test('429 → rateLimit', () {
      expect(
        AIErrorPresenter.categorize(
          const AIProviderException(message: 'x', statusCode: 429),
        ),
        AIErrorCategory.rateLimit,
      );
    });

    test('404 model-not-found → modelUnavailable', () {
      expect(
        AIErrorPresenter.categorize(
          const AIProviderException(
            message: 'model not found', statusCode: 404,
          ),
        ),
        AIErrorCategory.modelUnavailable,
      );
    });

    test('RESPONSE_BLOCKED → blocked', () {
      expect(
        AIErrorPresenter.categorize(
          const AIProviderException(
            message: 'x', errorCode: 'RESPONSE_BLOCKED',
          ),
        ),
        AIErrorCategory.blocked,
      );
    });

    test('parse-ish codes → invalidResponse', () {
      for (final code in const [
        'INVALID_JSON',
        'PARSE_ERROR',
        'EMPTY_RESPONSE',
        'NO_CANDIDATES',
      ]) {
        expect(
          AIErrorPresenter.categorize(
            AIProviderException(message: 'x', errorCode: code),
          ),
          AIErrorCategory.invalidResponse,
          reason: code,
        );
      }
    });

    test('TIMEOUT code → timeout', () {
      expect(
        AIErrorPresenter.categorize(
          const AIProviderException(message: 'x', errorCode: 'TIMEOUT'),
        ),
        AIErrorCategory.timeout,
      );
    });

    test('5xx → server', () {
      expect(
        AIErrorPresenter.categorize(
          const AIProviderException(message: 'x', statusCode: 503),
        ),
        AIErrorCategory.server,
      );
    });

    test('no status + originalError → network', () {
      expect(
        AIErrorPresenter.categorize(
          const AIProviderException(message: 'x', originalError: 'boom'),
        ),
        AIErrorCategory.network,
      );
    });
  });

  group('categorize – other inputs', () {
    test('an AIErrorCategory passes through unchanged', () {
      expect(
        AIErrorPresenter.categorize(AIErrorCategory.blocked),
        AIErrorCategory.blocked,
      );
    });

    test('a stable token string decodes back to its category', () {
      final token = AIErrorPresenter.tokenFor(
        const AIProviderException(message: 'x', statusCode: 401),
      );
      expect(AIErrorPresenter.categorize(token), AIErrorCategory.auth);
    });

    test('raw keyword strings are sniffed', () {
      expect(
        AIErrorPresenter.categorize('Request timed out'),
        AIErrorCategory.timeout,
      );
      expect(
        AIErrorPresenter.categorize('SocketException: failed'),
        AIErrorCategory.network,
      );
      expect(
        AIErrorPresenter.categorize('API key not configured'),
        AIErrorCategory.missingKey,
      );
    });

    test('FormatException → invalidResponse', () {
      expect(
        AIErrorPresenter.categorize(const FormatException('bad')),
        AIErrorCategory.invalidResponse,
      );
    });

    test('null / unrecognised → unknown', () {
      expect(AIErrorPresenter.categorize(null), AIErrorCategory.unknown);
      expect(
        AIErrorPresenter.categorize('something totally opaque'),
        AIErrorCategory.unknown,
      );
    });
  });

  group('token round-trip', () {
    test('tokenFor produces a prefixed token', () {
      final t = AIErrorPresenter.tokenFor(AIErrorCategory.network);
      expect(t.startsWith(AIErrorPresenter.tokenPrefix), isTrue);
    });

    test('categoryFromToken returns null for non-tokens', () {
      expect(AIErrorPresenter.categoryFromToken('hello world'), isNull);
    });

    test('every category round-trips through token', () {
      for (final c in AIErrorCategory.values) {
        final t = AIErrorPresenter.tokenFor(c);
        expect(AIErrorPresenter.categoryFromToken(t), c, reason: c.name);
      }
    });
  });

  group('localized presentation', () {
    test('present() returns a non-empty localized message for every category',
        () {
      for (final c in AIErrorCategory.values) {
        final msg = AIErrorPresenter.messageForCategory(c, l10n);
        expect(msg.trim(), isNotEmpty, reason: c.name);
      }
    });

    test('present() maps an exception to the same string as its category', () {
      const e = AIProviderException(message: 'x', statusCode: 401);
      expect(
        AIErrorPresenter.present(e, l10n),
        AIErrorPresenter.messageForCategory(AIErrorCategory.auth, l10n),
      );
    });
  });

  group('debugDetail', () {
    test('formats an AIProviderException with provider/status/code', () {
      const e = AIProviderException(
        message: 'boom',
        statusCode: 500,
        errorCode: 'X',
        providerId: 'gemini',
      );
      final d = AIErrorPresenter.debugDetail(e);
      expect(d, contains('gemini'));
      expect(d, contains('500'));
      expect(d, contains('boom'));
    });

    test('handles null', () {
      expect(AIErrorPresenter.debugDetail(null), 'null');
    });
  });
}
