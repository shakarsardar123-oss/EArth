import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/core/errors/network_error.dart';

void main() {
  group('NetworkErrorType', () {
    test('fromStatusCode returns correct type for known codes', () {
      expect(NetworkErrorType.fromStatusCode(400), NetworkErrorType.badRequest);
      expect(NetworkErrorType.fromStatusCode(401), NetworkErrorType.unauthorized);
      expect(NetworkErrorType.fromStatusCode(403), NetworkErrorType.forbidden);
      expect(NetworkErrorType.fromStatusCode(404), NetworkErrorType.notFound);
      expect(NetworkErrorType.fromStatusCode(429), NetworkErrorType.rateLimited);
      expect(NetworkErrorType.fromStatusCode(500), NetworkErrorType.serverError);
      expect(NetworkErrorType.fromStatusCode(503), NetworkErrorType.serverError);
    });

    test('fromStatusCode returns unknown for null', () {
      expect(NetworkErrorType.fromStatusCode(null), NetworkErrorType.unknown);
    });

    test('fromStatusCode returns unknown for unhandled codes', () {
      expect(NetworkErrorType.fromStatusCode(418), NetworkErrorType.unknown);
      expect(NetworkErrorType.fromStatusCode(302), NetworkErrorType.unknown);
    });
  });

  group('NetworkError', () {
    test('carries type, statusCode, and message', () {
      const error = NetworkError(
        type: NetworkErrorType.notFound,
        statusCode: 404,
        message: 'Not found',
      );
      expect(error.type, NetworkErrorType.notFound);
      expect(error.statusCode, 404);
      expect(error.message, 'Not found');
    });

    test('fromStatusCode factory works', () {
      final error = NetworkError.fromStatusCode(401, message: 'Unauthorized');
      expect(error.type, NetworkErrorType.unauthorized);
      expect(error.statusCode, 401);
      expect(error.message, 'Unauthorized');
    });

    test('timeout factory', () {
      final error = NetworkError.timeout();
      expect(error.type, NetworkErrorType.timeout);
      expect(error.message, 'Request timed out');
      expect(error.statusCode, isNull);
    });

    test('timeout factory with custom message', () {
      final error = NetworkError.timeout(message: 'Slow');
      expect(error.message, 'Slow');
    });

    test('noInternet factory', () {
      final error = NetworkError.noInternet();
      expect(error.type, NetworkErrorType.noInternet);
      expect(error.message, 'No internet connection');
    });

    test('malformedResponse factory', () {
      final error = NetworkError.malformedResponse();
      expect(error.type, NetworkErrorType.malformedResponse);
      expect(error.message, 'Malformed response from server');
    });

    test('isRetryable is true for retryable types', () {
      expect(const NetworkError(type: NetworkErrorType.timeout).isRetryable, isTrue);
      expect(const NetworkError(type: NetworkErrorType.noInternet).isRetryable, isTrue);
      expect(const NetworkError(type: NetworkErrorType.serverError).isRetryable, isTrue);
      expect(const NetworkError(type: NetworkErrorType.rateLimited).isRetryable, isTrue);
    });

    test('isRetryable is false for non-retryable types', () {
      expect(const NetworkError(type: NetworkErrorType.unauthorized).isRetryable, isFalse);
      expect(const NetworkError(type: NetworkErrorType.badRequest).isRetryable, isFalse);
      expect(const NetworkError(type: NetworkErrorType.notFound).isRetryable, isFalse);
      expect(const NetworkError(type: NetworkErrorType.forbidden).isRetryable, isFalse);
      expect(const NetworkError(type: NetworkErrorType.malformedResponse).isRetryable, isFalse);
      expect(const NetworkError(type: NetworkErrorType.unknown).isRetryable, isFalse);
    });

    test('toString includes relevant fields', () {
      const error = NetworkError(
        type: NetworkErrorType.serverError,
        statusCode: 500,
        message: 'Internal error',
      );
      final str = error.toString();
      expect(str, contains('NetworkError'));
      expect(str, contains('500'));
      expect(str, contains('Internal error'));
    });
  });
}
