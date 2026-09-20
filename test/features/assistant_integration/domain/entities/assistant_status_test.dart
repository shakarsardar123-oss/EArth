// Test file for AssistantStatus entity.
//
// Structural / mock-based tests — no Flutter SDK required to compile-review.
// These tests verify value semantics, copyWith, and convenience getters.

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/assistant_integration/domain/entities/assistant_status.dart';

void main() {
  group('AssistantAvailability', () {
    test('has three values: unsupported, available, active', () {
      expect(AssistantAvailability.values, hasLength(3));
      expect(AssistantAvailability.values,
          contains(AssistantAvailability.unsupported));
      expect(AssistantAvailability.values,
          contains(AssistantAvailability.available));
      expect(AssistantAvailability.values,
          contains(AssistantAvailability.active));
    });
  });

  group('AssistantStatus', () {
    test('default constructor has unsupported availability', () {
      const status = AssistantStatus();
      expect(status.availability, AssistantAvailability.unsupported);
      expect(status.currentDefaultPackage, isNull);
      expect(status.androidApiLevel, isNull);
      expect(status.lastChecked, isNull);
    });

    test('isAuraDefault is true only when availability is active', () {
      const active = AssistantStatus(availability: AssistantAvailability.active);
      const available = AssistantStatus(availability: AssistantAvailability.available);
      const unsupported = AssistantStatus(availability: AssistantAvailability.unsupported);

      expect(active.isAuraDefault, isTrue);
      expect(available.isAuraDefault, isFalse);
      expect(unsupported.isAuraDefault, isFalse);
    });

    test('canRequestDefault is true only when availability is available', () {
      const available = AssistantStatus(availability: AssistantAvailability.available);
      const active = AssistantStatus(availability: AssistantAvailability.active);
      const unsupported = AssistantStatus(availability: AssistantAvailability.unsupported);

      expect(available.canRequestDefault, isTrue);
      expect(active.canRequestDefault, isFalse);
      expect(unsupported.canRequestDefault, isFalse);
    });

    test('isUnsupported is true only when availability is unsupported', () {
      const unsupported = AssistantStatus(availability: AssistantAvailability.unsupported);
      const available = AssistantStatus(availability: AssistantAvailability.available);

      expect(unsupported.isUnsupported, isTrue);
      expect(available.isUnsupported, isFalse);
    });

    test('copyWith updates fields', () {
      const original = AssistantStatus(availability: AssistantAvailability.available);
      final updated = original.copyWith(
        availability: AssistantAvailability.active,
        currentDefaultPackage: 'com.aura.assistant',
        androidApiLevel: 33,
      );

      expect(updated.availability, AssistantAvailability.active);
      expect(updated.currentDefaultPackage, 'com.aura.assistant');
      expect(updated.androidApiLevel, 33);
      // lastChecked inherited from original (null)
      expect(updated.lastChecked, isNull);
    });

    test('copyWith clearCurrentDefaultPackage sets field to null', () {
      const status = AssistantStatus(currentDefaultPackage: 'com.other.app');
      final cleared = status.copyWith(clearCurrentDefaultPackage: true);
      expect(cleared.currentDefaultPackage, isNull);
    });

    test('equality based on availability, package, and apiLevel', () {
      const a = AssistantStatus(
        availability: AssistantAvailability.available,
        currentDefaultPackage: 'pkg',
        androidApiLevel: 33,
      );
      const b = AssistantStatus(
        availability: AssistantAvailability.available,
        currentDefaultPackage: 'pkg',
        androidApiLevel: 33,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('inequality when fields differ', () {
      const a = AssistantStatus(availability: AssistantAvailability.available);
      const b = AssistantStatus(availability: AssistantAvailability.active);
      expect(a, isNot(equals(b)));
    });

    test('toString includes key fields', () {
      const status = AssistantStatus(
        availability: AssistantAvailability.active,
        androidApiLevel: 34,
      );
      expect(status.toString(), contains('active'));
      expect(status.toString(), contains('34'));
    });
  });
}
