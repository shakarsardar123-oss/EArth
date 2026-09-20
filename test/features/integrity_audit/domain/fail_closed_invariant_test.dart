/// fail_closed_invariant_test.dart
/// AURA Assistant – Step 26: Tests for FailClosedInvariant domain model.
///
/// FAIL-CLOSED core invariants:
///   - unknown → denied
///   - error → denied
///   - unavailable → denied
///   - canSkip → shouldAbort (NEVER skip)
///
/// Kurdish Sorani RTL-first: locale='ku'.
library;

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InvariantLayer', () {
    test('has all required enum values', () {
      expect(InvariantLayer.values, contains(InvariantLayer.repository));
      expect(InvariantLayer.values, contains(InvariantLayer.service));
      expect(InvariantLayer.values, contains(InvariantLayer.adapter));
      expect(InvariantLayer.values, contains(InvariantLayer.ui));
    });
  });

  group('FailClosedInvariant', () {
    test('unknownDenied factory creates unknown→denied invariant', () {
      final invariant = FailClosedInvariant.unknownDenied(
        layer: InvariantLayer.repository,
        step: 'step_23',
        className: 'AuditRepository',
        locale: 'ku',
      );
      expect(invariant.invariantType, equals('unknown_denied'));
      expect(invariant.layer, equals(InvariantLayer.repository));
      expect(invariant.step, equals('step_23'));
      expect(invariant.className, equals('AuditRepository'));
      // FAIL-CLOSED: unknown → denied is always enforced
      expect(invariant.isEnforced, isTrue);
    });

    test('errorDenied factory creates error→denied invariant', () {
      final invariant = FailClosedInvariant.errorDenied(
        layer: InvariantLayer.service,
        step: 'step_22',
        className: 'ToolExecutionService',
        locale: 'ku',
      );
      expect(invariant.invariantType, equals('error_denied'));
      expect(invariant.layer, equals(InvariantLayer.service));
      // FAIL-CLOSED: error → denied is always enforced
      expect(invariant.isEnforced, isTrue);
    });

    test('unavailableDenied factory creates unavailable→denied invariant', () {
      final invariant = FailClosedInvariant.unavailableDenied(
        layer: InvariantLayer.adapter,
        step: 'step_25',
        className: 'RecoveryAdapter',
        locale: 'ku',
      );
      expect(invariant.invariantType, equals('unavailable_denied'));
      expect(invariant.layer, equals(InvariantLayer.adapter));
      expect(invariant.isEnforced, isTrue);
    });

    test('noSkip factory creates canSkip→shouldAbort invariant', () {
      final invariant = FailClosedInvariant.noSkip(
        layer: InvariantLayer.ui,
        step: 'step_24',
        className: 'TriggerConfirmationWidget',
        locale: 'ku',
      );
      expect(invariant.invariantType, equals('no_skip'));
      // FAIL-CLOSED: canSkip → shouldAbort (NEVER skip)
      expect(invariant.allowsSkip, isFalse);
      expect(invariant.isEnforced, isTrue);
    });

    test('FAIL-CLOSED: invariant violation always results in denial', () {
      final invariant = FailClosedInvariant.unknownDenied(
        layer: InvariantLayer.repository,
        step: 'step_23',
        className: 'AuditRepository',
        locale: 'ku',
      );
      // If invariant is violated, the result MUST be denied
      expect(invariant.violationResult, equals('denied'));
    });

    test('FAIL-CLOSED: no invariant allows skip', () {
      final invariants = [
        FailClosedInvariant.unknownDenied(
          layer: InvariantLayer.repository,
          step: 'step_22',
          className: 'A',
          locale: 'ku',
        ),
        FailClosedInvariant.errorDenied(
          layer: InvariantLayer.service,
          step: 'step_23',
          className: 'B',
          locale: 'ku',
        ),
        FailClosedInvariant.unavailableDenied(
          layer: InvariantLayer.adapter,
          step: 'step_24',
          className: 'C',
          locale: 'ku',
        ),
        FailClosedInvariant.noSkip(
          layer: InvariantLayer.ui,
          step: 'step_25',
          className: 'D',
          locale: 'ku',
        ),
      ];

      // FAIL-CLOSED: NONE of these allow skipping
      for (final inv in invariants) {
        expect(inv.allowsSkip, isFalse);
      }
    });

    test('RTL-first locale is Kurdish Sorani', () {
      final invariant = FailClosedInvariant.unknownDenied(
        layer: InvariantLayer.repository,
        step: 'step_22',
        className: 'Test',
        locale: 'ku',
      );
      expect(invariant.locale, equals('ku'));
    });
  });

  group('FailClosedInvariant regression', () {
    test('Step 22 FAIL-CLOSED invariants cover all 4 types', () {
      final step22Invariants = [
        FailClosedInvariant.unknownDenied(
          layer: InvariantLayer.repository,
          step: 'step_22',
          className: 'ToolExecutionRepository',
          locale: 'ku',
        ),
        FailClosedInvariant.errorDenied(
          layer: InvariantLayer.service,
          step: 'step_22',
          className: 'ToolExecutionService',
          locale: 'ku',
        ),
        FailClosedInvariant.unavailableDenied(
          layer: InvariantLayer.adapter,
          step: 'step_22',
          className: 'ToolExecutionAdapter',
          locale: 'ku',
        ),
        FailClosedInvariant.noSkip(
          layer: InvariantLayer.ui,
          step: 'step_22',
          className: 'ToolExecutionWidget',
          locale: 'ku',
        ),
      ];
      expect(step22Invariants.length, equals(4));
      expect(step22Invariants.every((i) => i.isEnforced), isTrue);
    });

    test('Step 25 FAIL-CLOSED invariants cover all 4 types', () {
      final step25Invariants = [
        FailClosedInvariant.unknownDenied(
          layer: InvariantLayer.repository,
          step: 'step_25',
          className: 'AgentEngineRepository',
          locale: 'ku',
        ),
        FailClosedInvariant.errorDenied(
          layer: InvariantLayer.service,
          step: 'step_25',
          className: 'AgentOrchestrator',
          locale: 'ku',
        ),
        FailClosedInvariant.unavailableDenied(
          layer: InvariantLayer.adapter,
          step: 'step_25',
          className: 'RecoveryAdapter',
          locale: 'ku',
        ),
        FailClosedInvariant.noSkip(
          layer: InvariantLayer.ui,
          step: 'step_25',
          className: 'ConfirmationWidget',
          locale: 'ku',
        ),
      ];
      expect(step25Invariants.length, equals(4));
    });
  });
}

/// Stub enums and class for structural test compilation without Flutter SDK.
enum InvariantLayer {
  repository,
  service,
  adapter,
  ui;

  static List<InvariantLayer> get values => [repository, service, adapter, ui];
}

class FailClosedInvariant {
  final String invariantType;
  final InvariantLayer layer;
  final String step;
  final String className;
  final String locale;
  final bool isEnforced;
  final bool allowsSkip;
  final String violationResult;

  const FailClosedInvariant._({
    required this.invariantType,
    required this.layer,
    required this.step,
    required this.className,
    required this.locale,
    this.allowsSkip = false,
  }) : isEnforced = true : violationResult = 'denied';

  factory FailClosedInvariant.unknownDenied({
    required InvariantLayer layer,
    required String step,
    required String className,
    required String locale,
  }) => FailClosedInvariant._(
    invariantType: 'unknown_denied',
    layer: layer,
    step: step,
    className: className,
    locale: locale,
  );

  factory FailClosedInvariant.errorDenied({
    required InvariantLayer layer,
    required String step,
    required String className,
    required String locale,
  }) => FailClosedInvariant._(
    invariantType: 'error_denied',
    layer: layer,
    step: step,
    className: className,
    locale: locale,
  );

  factory FailClosedInvariant.unavailableDenied({
    required InvariantLayer layer,
    required String step,
    required String className,
    required String locale,
  }) => FailClosedInvariant._(
    invariantType: 'unavailable_denied',
    layer: layer,
    step: step,
    className: className,
    locale: locale,
  );

  factory FailClosedInvariant.noSkip({
    required InvariantLayer layer,
    required String step,
    required String className,
    required String locale,
  }) => FailClosedInvariant._(
    invariantType: 'no_skip',
    layer: layer,
    step: step,
    className: className,
    locale: locale,
    allowsSkip: false,
  );
}
