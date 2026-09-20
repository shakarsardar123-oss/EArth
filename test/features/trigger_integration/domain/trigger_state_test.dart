/// Step 24 — Trigger State Tests
///
/// Structural tests for TriggerPhase enum and TriggerState class.
/// FAIL-CLOSED: unrecognized/error → denied or failed.
/// No Flutter/Dart SDK — structural validation only, NEVER claim runtime test results.

import 'package:aura_assistant/features/trigger_integration/domain/value_objects/trigger_state.dart';

void main() {
  group('TriggerPhase', () {
    test('has all expected phases', () {
      expect(TriggerPhase.values, containsAll([
        TriggerPhase.idle,
        TriggerPhase.received,
        TriggerPhase.validating,
        TriggerPhase.authorized,
        TriggerPhase.launching,
        TriggerPhase.launched,
        TriggerPhase.denied,
        TriggerPhase.failed,
        TriggerPhase.unavailable,
      ]));
    });

    test('terminal phases are correctly identified', () {
      expect(TriggerPhase.denied.isTerminal, isTrue);
      expect(TriggerPhase.failed.isTerminal, isTrue);
      expect(TriggerPhase.unavailable.isTerminal, isTrue);
      expect(TriggerPhase.launched.isTerminal, isTrue);
    });

    test('non-terminal phases are not terminal', () {
      expect(TriggerPhase.idle.isTerminal, isFalse);
      expect(TriggerPhase.received.isTerminal, isFalse);
      expect(TriggerPhase.validating.isTerminal, isFalse);
      expect(TriggerPhase.authorized.isTerminal, isFalse);
      expect(TriggerPhase.launching.isTerminal, isFalse);
    });

    test('FAIL-CLOSED: fromName with unknown string returns failed', () {
      expect(TriggerPhase.fromName('nonexistent'),
          equals(TriggerPhase.failed));
      expect(TriggerPhase.fromName(''),
          equals(TriggerPhase.failed));
    });

    test('fromName parses known phases correctly', () {
      expect(TriggerPhase.fromName('idle'), equals(TriggerPhase.idle));
      expect(TriggerPhase.fromName('launched'), equals(TriggerPhase.launched));
      expect(TriggerPhase.fromName('denied'), equals(TriggerPhase.denied));
    });
  });

  group('TriggerState', () {
    test('initial factory creates idle state', () {
      final state = TriggerState.initial('test-id');
      expect(state.triggerId, equals('test-id'));
      expect(state.phase, equals(TriggerPhase.idle));
      expect(state.errorMessage, isNull);
      expect(state.denialReason, isNull);
    });

    test('denied factory creates denied state with reason', () {
      final state = TriggerState.denied(
        triggerId: 'test-id',
        denialReason: 'security_policy',
      );
      expect(state.triggerId, equals('test-id'));
      expect(state.phase, equals(TriggerPhase.denied));
      expect(state.denialReason, equals('security_policy'));
    });

    test('failed factory creates failed state with message', () {
      final state = TriggerState.failed(
        triggerId: 'test-id',
        errorMessage: 'engine_crash',
      );
      expect(state.triggerId, equals('test-id'));
      expect(state.phase, equals(TriggerPhase.failed));
      expect(state.errorMessage, equals('engine_crash'));
    });

    test('unavailable factory creates unavailable state', () {
      final state = TriggerState.unavailable(
        triggerId: 'test-id',
        errorMessage: 'engine_not_running',
      );
      expect(state.phase, equals(TriggerPhase.unavailable));
      expect(state.errorMessage, equals('engine_not_running'));
    });

    test('launched factory creates launched state', () {
      final state = TriggerState.launched('test-id');
      expect(state.triggerId, equals('test-id'));
      expect(state.phase, equals(TriggerPhase.launched));
    });

    test('copyWith creates modified copy preserving triggerId', () {
      final original = TriggerState.initial('test-id');
      final modified = original.copyWith(phase: TriggerPhase.denied,
          denialReason: 'policy');
      expect(modified.triggerId, equals('test-id'));
      expect(modified.phase, equals(TriggerPhase.denied));
      expect(modified.denialReason, equals('policy'));
      // Original unchanged
      expect(original.phase, equals(TriggerPhase.idle));
    });

    test('toString contains triggerId and phase', () {
      final state = TriggerState.initial('abc-123');
      final str = state.toString();
      expect(str, contains('abc-123'));
      expect(str, contains('idle'));
    });
  });
}
