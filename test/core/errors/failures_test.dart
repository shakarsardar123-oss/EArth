import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/core/errors/failures.dart';

void main() {
  group('Failure (base)', () {
    test('concrete subclass carries message and optional code', () {
      const failure = StorageFailure(message: 'something broke', code: 'E001');
      expect(failure.message, 'something broke');
      expect(failure.code, 'E001');
    });

    test('code defaults to null', () {
      const failure = UnexpectedFailure(message: 'no code');
      expect(failure.code, isNull);
    });

    test('toString includes message and code', () {
      const failure = StorageFailure(message: 'err', code: 'X');
      expect(failure.toString(), contains('err'));
      expect(failure.toString(), contains('X'));
    });
  });

  group('NetworkFailure', () {
    test('inherits message and code', () {
      const failure = NetworkFailure(message: 'timeout', code: 'NET01');
      expect(failure.message, 'timeout');
      expect(failure.code, 'NET01');
    });

    test('has optional statusCode', () {
      const failure = NetworkFailure(message: 'not found', statusCode: 404);
      expect(failure.statusCode, 404);
    });

    test('statusCode defaults to null', () {
      const failure = NetworkFailure(message: 'generic');
      expect(failure.statusCode, isNull);
    });

    test('is a Failure', () {
      const failure = NetworkFailure(message: 'net err');
      expect(failure, isA<Failure>());
    });
  });

  group('StorageFailure', () {
    test('inherits message and code', () {
      const failure = StorageFailure(message: 'write failed', code: 'ST01');
      expect(failure.message, 'write failed');
      expect(failure.code, 'ST01');
    });

    test('is a Failure', () {
      const failure = StorageFailure(message: 'st');
      expect(failure, isA<Failure>());
    });
  });

  group('UnexpectedFailure', () {
    test('inherits message and code', () {
      const failure = UnexpectedFailure(message: 'surprise', code: 'UNX');
      expect(failure.message, 'surprise');
      expect(failure.code, 'UNX');
    });

    test('is a Failure', () {
      const failure = UnexpectedFailure(message: 'u');
      expect(failure, isA<Failure>());
    });
  });
}
