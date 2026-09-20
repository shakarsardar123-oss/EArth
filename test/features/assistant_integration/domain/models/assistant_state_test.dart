// Test file for AssistantState model.
//
// Structural / mock-based tests — verify lifecycle enum, state
// construction, copyWith, clear* flags, and convenience getters.

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/assistant_integration/domain/models/assistant_state.dart';
import 'package:aura_assistant/features/assistant_integration/domain/entities/assistant_status.dart';
import 'package:aura_assistant/features/assistant_integration/domain/entities/assistant_invocation.dart';

void main() {
  final _now = DateTime(2026, 1, 1);

  group('AssistantLifecycle', () {
    test('has nine expected values', () {
      expect(AssistantLifecycle.values, hasLength(9));
      expect(AssistantLifecycle.values, contains(AssistantLifecycle.uninitialized));
      expect(AssistantLifecycle.values, contains(AssistantLifecycle.checking));
      expect(AssistantLifecycle.values, contains(AssistantLifecycle.available));
      expect(AssistantLifecycle.values, contains(AssistantLifecycle.requesting));
      expect(AssistantLifecycle.values, contains(AssistantLifecycle.active));
      expect(AssistantLifecycle.values, contains(AssistantLifecycle.invoked));
      expect(AssistantLifecycle.values, contains(AssistantLifecycle.cancelled));
      expect(AssistantLifecycle.values, contains(AssistantLifecycle.failed));
      expect(AssistantLifecycle.values, contains(AssistantLifecycle.unsupported));
    });
  });

  group('AssistantState', () {
    test('default constructor has uninitialized lifecycle', () {
      final state = AssistantState(updatedAt: _now);
      expect(state.lifecycle, AssistantLifecycle.uninitialized);
      expect(state.currentInvocation, isNull);
      expect(state.errorMessage, isNull);
    });

    test('isDefaultAssistant is true when lifecycle is active', () {
      final state = AssistantState(
        lifecycle: AssistantLifecycle.active,
        updatedAt: _now,
      );
      expect(state.isDefaultAssistant, isTrue);
    });

    test('isDefaultAssistant is false for other lifecycles', () {
      final state = AssistantState(
        lifecycle: AssistantLifecycle.available,
        updatedAt: _now,
      );
      expect(state.isDefaultAssistant, isFalse);
    });

    test('isInvoked is true when lifecycle is invoked', () {
      final state = AssistantState(
        lifecycle: AssistantLifecycle.invoked,
        updatedAt: _now,
      );
      expect(state.isInvoked, isTrue);
    });

    test('canRequestDefault is true when lifecycle is available', () {
      final state = AssistantState(
        lifecycle: AssistantLifecycle.available,
        updatedAt: _now,
      );
      expect(state.canRequestDefault, isTrue);
    });

    test('hasError is true when lifecycle is failed', () {
      final state = AssistantState(
        lifecycle: AssistantLifecycle.failed,
        errorMessage: 'some error',
        updatedAt: _now,
      );
      expect(state.hasError, isTrue);
    });

    test('copyWith updates lifecycle and preserves other fields', () {
      final original = AssistantState(
        lifecycle: AssistantLifecycle.available,
        status: const AssistantStatus(availability: AssistantAvailability.available),
        updatedAt: _now,
      );
      final updated = original.copyWith(
        lifecycle: AssistantLifecycle.active,
      );
      expect(updated.lifecycle, AssistantLifecycle.active);
      expect(updated.status.availability, AssistantAvailability.available);
    });

    test('copyWith clearCurrentInvocation sets invocation to null', () {
      final invocation = AssistantInvocation(
        invokedAt: _now,
        statusAtInvocation: const AssistantStatus(),
      );
      final withInvocation = AssistantState(
        currentInvocation: invocation,
        updatedAt: _now,
      );
      final cleared = withInvocation.copyWith(clearCurrentInvocation: true);
      expect(cleared.currentInvocation, isNull);
    });

    test('copyWith clearErrorMessage sets message to null', () {
      final withError = AssistantState(
        lifecycle: AssistantLifecycle.failed,
        errorMessage: 'oops',
        updatedAt: _now,
      );
      final cleared = withError.copyWith(clearErrorMessage: true);
      expect(cleared.errorMessage, isNull);
    });

    test('equality based on lifecycle, status, invocation, error', () {
      final a = AssistantState(
        lifecycle: AssistantLifecycle.active,
        errorMessage: null,
        updatedAt: _now,
      );
      final b = AssistantState(
        lifecycle: AssistantLifecycle.active,
        errorMessage: null,
        updatedAt: _now,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('inequality when lifecycle differs', () {
      final a = AssistantState(
        lifecycle: AssistantLifecycle.active,
        updatedAt: _now,
      );
      final b = AssistantState(
        lifecycle: AssistantLifecycle.failed,
        updatedAt: _now,
      );
      expect(a, isNot(equals(b)));
    });

    test('toString includes lifecycle and status', () {
      final state = AssistantState(
        lifecycle: AssistantLifecycle.active,
        updatedAt: _now,
      );
      expect(state.toString(), contains('active'));
    });
  });
}
