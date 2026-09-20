import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/core/errors/result.dart';
import 'package:aura_assistant/core/errors/failures.dart';

void main() {
  group('Result', () {
    group('Success', () {
      late Result<int, Failure> success;

      setUp(() {
        success = const Result.success(42);
      });

      test('isSuccess returns true', () {
        expect(success.isSuccess, isTrue);
      });

      test('isFailure returns false', () {
        expect(success.isFailure, isFalse);
      });

      test('map transforms the success value', () {
        final mapped = success.map((v) => v.toString());
        expect(mapped.isSuccess, isTrue);
        expect(mapped.when(success: (v) => v, failure: (_) => 'fail'), '42');
      });

      test('mapFailure does not change the success value', () {
        final mapped = success.mapFailure((f) => const UnexpectedFailure(message: 'x'));
        expect(mapped.isSuccess, isTrue);
        expect(mapped.when(success: (v) => v, failure: (_) => -1), 42);
      });

      test('fold returns onSuccess result', () {
        final result = success.fold(
          onSuccess: (v) => 'ok:$v',
          onFailure: (f) => 'err:${f.message}',
        );
        expect(result, 'ok:42');
      });

      test('when returns success branch', () {
        final result = success.when(
          success: (v) => v * 2,
          failure: (f) => -1,
        );
        expect(result, 84);
      });

      test('getOrElse returns the value', () {
        expect(success.getOrElse(() => 0), 42);
      });

      test('toString returns Success(value)', () {
        expect(success.toString(), 'Success(42)');
      });
    });

    group('FailureResult', () {
      late Result<int, Failure> failure;
      const testFailure = StorageFailure(message: 'disk full');

      setUp(() {
        failure = const Result.failure(testFailure);
      });

      test('isSuccess returns false', () {
        expect(failure.isSuccess, isFalse);
      });

      test('isFailure returns true', () {
        expect(failure.isFailure, isTrue);
      });

      test('map returns a failure with the same failure', () {
        final mapped = failure.map((v) => v.toString());
        expect(mapped.isFailure, isTrue);
      });

      test('mapFailure transforms the failure', () {
        final mapped = failure.mapFailure(
          (f) => NetworkFailure(message: f.message, statusCode: 500),
        );
        expect(mapped.isFailure, isTrue);
        final netFail = mapped.when(success: (_) => null, failure: (f) => f);
        expect(netFail, isA<NetworkFailure>());
      });

      test('fold returns onFailure result', () {
        final result = failure.fold(
          onSuccess: (v) => 'ok:$v',
          onFailure: (f) => 'err:${f.message}',
        );
        expect(result, 'err:disk full');
      });

      test('when returns failure branch', () {
        final result = failure.when(
          success: (v) => v * 2,
          failure: (f) => f.message,
        );
        expect(result, 'disk full');
      });

      test('getOrElse returns the orElse value', () {
        expect(failure.getOrElse(() => 0), 0);
      });

      test('toString contains Failure', () {
        expect(failure.toString(), contains('Failure'));
      });
    });
  });
}
