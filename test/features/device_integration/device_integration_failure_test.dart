/// Tests for DeviceIntegrationFailure and DeviceIntegrationFailurePhase.
/// Covers: 7 phases, 7 named factories, equality semantics.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/device_integration/domain/models/device_integration_failure.dart';
import 'package:aura_assistant/features/device_integration/domain/entities/device_action.dart';
import 'package:aura_assistant/core/errors/result.dart';

void main() {
  // ─── DeviceIntegrationFailurePhase ────────────────────────────────
  group('DeviceIntegrationFailurePhase', () {
    test('has all seven phases', () {
      expect(DeviceIntegrationFailurePhase.values.length, 7);
      expect(DeviceIntegrationFailurePhase.values,
          contains(DeviceIntegrationFailurePhase.validation));
      expect(DeviceIntegrationFailurePhase.values,
          contains(DeviceIntegrationFailurePhase.permission));
      expect(DeviceIntegrationFailurePhase.values,
          contains(DeviceIntegrationFailurePhase.security));
      expect(DeviceIntegrationFailurePhase.values,
          contains(DeviceIntegrationFailurePhase.execution));
      expect(DeviceIntegrationFailurePhase.values,
          contains(DeviceIntegrationFailurePhase.verification));
      expect(DeviceIntegrationFailurePhase.values,
          contains(DeviceIntegrationFailurePhase.targetResolution));
      expect(DeviceIntegrationFailurePhase.values,
          contains(DeviceIntegrationFailurePhase.cancellation));
    });
  });

  // ─── DeviceIntegrationFailure factories ──────────────────────────
  group('DeviceIntegrationFailure factories', () {
    test('validation factory creates correct phase', () {
      final f = DeviceIntegrationFailure.validation('bad structure');
      expect(f.phase, DeviceIntegrationFailurePhase.validation);
      expect(f.message, 'bad structure');
      expect(f.action, isNull);
      expect(f.cause, isNull);
    });

    test('permission factory creates correct phase', () {
      final f = DeviceIntegrationFailure.permission('accessibility denied');
      expect(f.phase, DeviceIntegrationFailurePhase.permission);
      expect(f.message, 'accessibility denied');
    });

    test('security factory creates correct phase', () {
      final f = DeviceIntegrationFailure.security('prohibited action');
      expect(f.phase, DeviceIntegrationFailurePhase.security);
      expect(f.message, 'prohibited action');
    });

    test('execution factory creates correct phase', () {
      final f = DeviceIntegrationFailure.execution('executor failed');
      expect(f.phase, DeviceIntegrationFailurePhase.execution);
      expect(f.message, 'executor failed');
    });

    test('verification factory creates correct phase', () {
      final f = DeviceIntegrationFailure.verification('mismatch');
      expect(f.phase, DeviceIntegrationFailurePhase.verification);
      expect(f.message, 'mismatch');
    });

    test('targetResolution factory creates correct phase', () {
      final f =
          DeviceIntegrationFailure.targetResolution('target not found');
      expect(f.phase, DeviceIntegrationFailurePhase.targetResolution);
      expect(f.message, 'target not found');
    });

    test('cancellation factory creates correct phase', () {
      final f = DeviceIntegrationFailure.cancellation('user cancelled');
      expect(f.phase, DeviceIntegrationFailurePhase.cancellation);
      expect(f.message, 'user cancelled');
    });
  });

  // ─── DeviceIntegrationFailure with action/cause ──────────────────
  group('DeviceIntegrationFailure action and cause', () {
    test('carries optional action', () {
      final action = DeviceAction.tap(
        targetPoint: const NormalizedPoint(x: 0.5, y: 0.5),
      );
      final f = DeviceIntegrationFailure.execution(
        'failed',
        action: action,
      );
      expect(f.action, isNotNull);
      expect(f.action!.type, DeviceActionType.tap);
    });

    test('carries optional cause', () {
      final inner = DeviceIntegrationFailure.validation('inner error');
      final f = DeviceIntegrationFailure.execution(
        'outer error',
        cause: inner,
      );
      expect(f.cause, isNotNull);
      expect(f.cause!.phase, DeviceIntegrationFailurePhase.validation);
    });
  });

  // ─── Equality ───────────────────────────────────────────────────
  group('DeviceIntegrationFailure equality', () {
    test('same phase and message are equal', () {
      final a = DeviceIntegrationFailure.validation('same');
      final b = DeviceIntegrationFailure.validation('same');
      expect(a, equals(b));
    });

    test('different phase or message are not equal', () {
      final a = DeviceIntegrationFailure.validation('msg');
      final b = DeviceIntegrationFailure.permission('msg');
      final c = DeviceIntegrationFailure.validation('other');
      expect(a, isNot(equals(b)));
      expect(a, isNot(equals(c)));
    });

    test('equality ignores action and cause', () {
      final action = DeviceAction.tap(
        targetPoint: const NormalizedPoint(x: 0.5, y: 0.5),
      );
      final a = DeviceIntegrationFailure.execution('msg');
      final b = DeviceIntegrationFailure.execution('msg', action: action);
      expect(a, equals(b));
    });
  });

  // ─── DeviceIntegrationResult typedef ──────────────────────────────
  group('DeviceIntegrationResult', () {
    test('success wraps value', () {
      final result = Result<NormalizedPoint, DeviceIntegrationFailure>.success(
        const NormalizedPoint(x: 0.5, y: 0.5),
      );
      expect(result.isFailure, isFalse);
      expect(result.valueOrNull, const NormalizedPoint(x: 0.5, y: 0.5));
    });

    test('failure wraps failure', () {
      final result = Result<NormalizedPoint, DeviceIntegrationFailure>.failure(
        DeviceIntegrationFailure.targetResolution('not found'),
      );
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isNotNull);
      expect(result.failureOrNull!.phase,
          DeviceIntegrationFailurePhase.targetResolution);
    });
  });
}
