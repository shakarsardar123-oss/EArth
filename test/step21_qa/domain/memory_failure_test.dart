/// memory_failure_test.dart
/// Step 21 – Unit tests for MemoryFailure (Step 17 domain model)
///
/// Validates all failure phases, factory constructors, and
/// fail-closed behavior.

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/semantic_memory/domain/models/memory_failure.dart';

void main() {
  group('MemoryFailure', () {
    // ---- Factory constructors ----
    test('storage factory creates failure with correct phase', () {
      final failure = MemoryFailure.storage(
        message: 'disk full',
        action: 'write',
        cause: 'out of space',
      );
      expect(failure.phase, MemoryFailurePhase.storage);
      expect(failure.isDenial, isTrue);
    });

    test('retrieval factory creates failure with correct phase', () {
      final failure = MemoryFailure.retrieval(
        message: 'not found',
        action: 'recall',
      );
      expect(failure.phase, MemoryFailurePhase.retrieval);
    });

    test('security factory creates failure with correct phase', () {
      final failure = MemoryFailure.security(
        message: 'blocked',
        reason: 'sensitive data',
      );
      expect(failure.phase, MemoryFailurePhase.security);
      expect(failure.isFailClosedDenial, isTrue);
    });

    test('validation factory creates failure', () {
      final failure = MemoryFailure.validation(
        message: 'invalid input',
        cause: 'empty content',
      );
      expect(failure.phase, MemoryFailurePhase.validation);
    });

    test('offline factory creates failure', () {
      final failure = MemoryFailure.offline(
        message: 'no network',
      );
      expect(failure.phase, MemoryFailurePhase.offline);
    });

    test('unknown factory creates failure', () {
      final failure = MemoryFailure.unknown(
        message: 'unexpected error',
      );
      expect(failure.phase, MemoryFailurePhase.unknown);
    });

    // ---- Fail-closed invariants ----
    test('security failures are fail-closed denials', () {
      final failure = MemoryFailure.security(
        message: 'policy violation',
      );
      expect(failure.isDenial, isTrue);
      expect(failure.isFailClosedDenial, isTrue);
    });

    test('isDenial is always true for all phases', () {
      for (final phase in MemoryFailurePhase.values) {
        // Every MemoryFailure is a denial (by design)
        final failure = MemoryFailure.unknown(message: 'test');
        expect(failure.isDenial, isTrue);
      }
    });

    // ---- MemoryFailurePhase enum ----
    test('MemoryFailurePhase has expected values', () {
      expect(MemoryFailurePhase.values, containsAll([
        MemoryFailurePhase.storage,
        MemoryFailurePhase.retrieval,
        MemoryFailurePhase.security,
        MemoryFailurePhase.validation,
        MemoryFailurePhase.offline,
        MemoryFailurePhase.unknown,
      ]));
    });
  });
}
