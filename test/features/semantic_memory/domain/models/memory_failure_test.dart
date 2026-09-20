/// memory_failure_test.dart
/// Structural tests for MemoryFailure and MemoryResult.
library;

import 'package:test/test.dart';

// ─── Inline mirrors for structural testing ──────────────────────────

enum MemoryFailurePhase { storage, embedding, search, policy, unknown }

mixin _MemoryFailureBase {
  MemoryFailurePhase get phase;
  String get message;
  String? get action;
  Object? get cause;
}

class MemoryFailure with _MemoryFailureBase {
  final MemoryFailurePhase _phase;
  @override
  final String message;
  @override
  final String? action;
  @override
  final Object? cause;

  MemoryFailure._({required MemoryFailurePhase phase, required this.message, this.action, this.cause})
    : _phase = phase;

  @override
  MemoryFailurePhase get phase => _phase;

  factory MemoryFailure.storage({required String message, String? action, Object? cause}) =
      _StorageFailure;
  factory MemoryFailure.embedding({required String message, String? action, Object? cause}) =
      _EmbeddingFailure;
  factory MemoryFailure.search({required String message, String? action, Object? cause}) =
      _SearchFailure;
  factory MemoryFailure.policy({required String message, String? action, Object? cause}) =
      _PolicyFailure;
  factory MemoryFailure.unknown({required String message, String? action, Object? cause}) =
      _UnknownFailure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemoryFailure && _phase == other._phase && message == other.message;

  @override
  int get hashCode => Object.hash(_phase, message);

  @override
  String toString() => 'MemoryFailure(phase: $_phase, message: $message)';
}

class _StorageFailure extends MemoryFailure {
  _StorageFailure({required String message, String? action, Object? cause})
    : super._(phase: MemoryFailurePhase.storage, message: message, action: action, cause: cause);
}
class _EmbeddingFailure extends MemoryFailure {
  _EmbeddingFailure({required String message, String? action, Object? cause})
    : super._(phase: MemoryFailurePhase.embedding, message: message, action: action, cause: cause);
}
class _SearchFailure extends MemoryFailure {
  _SearchFailure({required String message, String? action, Object? cause})
    : super._(phase: MemoryFailurePhase.search, message: message, action: action, cause: cause);
}
class _PolicyFailure extends MemoryFailure {
  _PolicyFailure({required String message, String? action, Object? cause})
    : super._(phase: MemoryFailurePhase.policy, message: message, action: action, cause: cause);
}
class _UnknownFailure extends MemoryFailure {
  _UnknownFailure({required String message, String? action, Object? cause})
    : super._(phase: MemoryFailurePhase.unknown, message: message, action: action, cause: cause);
}

// Minimal Result mirror
typedef MemoryResult<T> = Result<T, MemoryFailure>;

class Result<S, F> {
  final S? _success;
  final F? _failure;
  final bool _isSuccess;

  Result._(this._success, this._failure, this._isSuccess);

  factory Result.success(S value) => Result._(value, null, true);
  factory Result.failure(F failure) => Result._(null, failure, false);

  bool get isSuccess => _isSuccess;
  bool get isFailure => !_isSuccess;

  S get value => _success as S;
  F get failure => _failure as F;

  R fold<R>(R Function(S) onSuccess, R Function(F) onFailure) =>
      _isSuccess ? onSuccess(_success as S) : onFailure(_failure as F);
}

void main() {
  group('MemoryFailurePhase', () {
    test('has 5 values', () {
      expect(MemoryFailurePhase.values, hasLength(5));
    });

    test('contains expected phases', () {
      expect(MemoryFailurePhase.values, containsAll([
        MemoryFailurePhase.storage,
        MemoryFailurePhase.embedding,
        MemoryFailurePhase.search,
        MemoryFailurePhase.policy,
        MemoryFailurePhase.unknown,
      ]));
    });
  });

  group('MemoryFailure', () {
    test('storage factory creates with storage phase', () {
      final f = MemoryFailure.storage(message: 'db error');
      expect(f.phase, MemoryFailurePhase.storage);
      expect(f.message, 'db error');
    });

    test('embedding factory creates with embedding phase', () {
      final f = MemoryFailure.embedding(message: 'embed fail');
      expect(f.phase, MemoryFailurePhase.embedding);
    });

    test('search factory creates with search phase', () {
      final f = MemoryFailure.search(message: 'search fail');
      expect(f.phase, MemoryFailurePhase.search);
    });

    test('policy factory creates with policy phase', () {
      final f = MemoryFailure.policy(message: 'sensitive data');
      expect(f.phase, MemoryFailurePhase.policy);
    });

    test('unknown factory creates with unknown phase', () {
      final f = MemoryFailure.unknown(message: '???');
      expect(f.phase, MemoryFailurePhase.unknown);
    });

    test('optional action and cause fields', () {
      final f = MemoryFailure.storage(
        message: 'err',
        action: 'retry',
        cause: Exception('boom'),
      );
      expect(f.action, 'retry');
      expect(f.cause, isNotNull);
    });

    test('equality based on phase and message', () {
      final a = MemoryFailure.storage(message: 'err');
      final b = MemoryFailure.storage(message: 'err');
      final c = MemoryFailure.storage(message: 'different');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('toString includes phase and message', () {
      final f = MemoryFailure.storage(message: 'oops');
      expect(f.toString(), contains('storage'));
      expect(f.toString(), contains('oops'));
    });
  });

  group('MemoryResult<T>', () {
    test('success result', () {
      final result = MemoryResult<int>.success(42);
      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.value, 42);
    });

    test('failure result', () {
      final result = MemoryResult<int>.failure(
        MemoryFailure.storage(message: 'fail'),
      );
      expect(result.isFailure, isTrue);
      expect(result.isSuccess, isFalse);
      expect(result.failure.phase, MemoryFailurePhase.storage);
    });

    test('fold on success', () {
      final result = MemoryResult<String>.success('ok');
      expect(
        result.fold((s) => 'success:$s', (f) => 'failure'),
        'success:ok',
      );
    });

    test('fold on failure', () {
      final result = MemoryResult<String>.failure(
        MemoryFailure.policy(message: 'sensitive'),
      );
      expect(
        result.fold((s) => 'success', (f) => 'failure:${f.message}'),
        'failure:sensitive',
      );
    });
  });
}
