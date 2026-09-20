/// Tests for ActionValidator.
/// Covers: validation pipeline (structural fail, security fail,
/// permission fail, success), static helpers.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/device_integration/application/action_validator.dart';
import 'package:aura_assistant/features/device_integration/domain/entities/device_action.dart';
import 'package:aura_assistant/features/device_integration/domain/models/device_integration_failure.dart';
import 'package:aura_assistant/features/device_integration/domain/models/permission_status.dart';
import 'package:aura_assistant/features/device_integration/domain/models/security_verdict.dart';
import 'package:aura_assistant/core/errors/result.dart';

/// Fake PermissionManager for testing.
class FakePermissionManager implements PermissionManager {
  final Map<DevicePermission, PermissionStatus> _statuses;
  bool _shouldFailRequest = false;

  FakePermissionManager({
    Map<DevicePermission, PermissionStatus>? initialStatuses,
  }) : _statuses = initialStatuses ??
            {
              DevicePermission.accessibility: PermissionStatus.granted,
              DevicePermission.overlay: PermissionStatus.granted,
              DevicePermission.screenCapture: PermissionStatus.granted,
            };

  void setShouldFailRequest(bool value) => _shouldFailRequest = value;

  @override
  Future<PermissionStatus> checkStatus(DevicePermission permission) async =>
      _statuses[permission] ?? PermissionStatus.notRequested;

  @override
  Future<PermissionResult> request(
      Iterable<DevicePermission> permissions) async {
    if (_shouldFailRequest) {
      return PermissionResult(statuses: {
        for (final p in permissions) p: PermissionStatus.denied,
      });
    }
    // Grant all requested
    final newStatuses = <DevicePermission, PermissionStatus>{};
    for (final p in permissions) {
      newStatuses[p] = PermissionStatus.granted;
      _statuses[p] = PermissionStatus.granted;
    }
    return PermissionResult(statuses: newStatuses);
  }

  @override
  Future<PermissionResult> checkAll() async =>
      PermissionResult(statuses: Map.from(_statuses));

  @override
  Future<PermissionResult> requestAll() async => request(DevicePermission.values);

  @override
  Future<Result<void, DeviceIntegrationFailure>> openSettings() async =>
      Result.success(null);
}

void main() {
  late ActionValidator validator;
  late FakePermissionManager permissionManager;

  setUp(() {
    permissionManager = FakePermissionManager();
    validator = ActionValidator(permissionManager: permissionManager);
  });

  // ─── Successful validation ────────────────────────────────────────
  group('ActionValidator.validate success', () {
    test('valid tap action passes all checks', () async {
      final action = DeviceAction.tap(
        targetPoint: const NormalizedPoint(x: 0.5, y: 0.5),
        targetLabel: 'button',
      );
      final result = await validator.validate(action);
      expect(result.isFailure, isFalse);
      expect(result.valueOrNull, isNotNull);
      expect(result.valueOrNull!.type, DeviceActionType.tap);
    });

    test('valid back action passes all checks', () async {
      final action = DeviceAction.back();
      final result = await validator.validate(action);
      expect(result.isFailure, isFalse);
    });

    test('valid openApp action passes all checks', () async {
      final action = DeviceAction.openApp(packageName: 'com.example.app');
      final result = await validator.validate(action);
      expect(result.isFailure, isFalse);
    });

    test('valid swipe action passes all checks', () async {
      final action = DeviceAction.swipe(
        swipeStart: const NormalizedPoint(x: 0.5, y: 0.8),
        swipeEnd: const NormalizedPoint(x: 0.5, y: 0.2),
      );
      final result = await validator.validate(action);
      expect(result.isFailure, isFalse);
    });
  });

  // ─── Security failure ─────────────────────────────────────────────
  group('ActionValidator.validate security failure', () {
    test('action with prohibited target label is rejected', () async {
      final action = DeviceAction.tap(
        targetPoint: const NormalizedPoint(x: 0.5, y: 0.5),
        targetLabel: 'aimbot',
      );
      final result = await validator.validate(action);
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull!.phase,
          DeviceIntegrationFailurePhase.security);
    });

    test('action with cheat target label is rejected', () async {
      final action = DeviceAction.tap(
        targetPoint: const NormalizedPoint(x: 0.5, y: 0.5),
        targetLabel: 'cheat button',
      );
      final result = await validator.validate(action);
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull!.phase,
          DeviceIntegrationFailurePhase.security);
    });
  });

  // ─── Permission failure ─────────────────────────────────────────
  group('ActionValidator.validate permission failure', () {
    test('action denied when accessibility is not granted', () async {
      permissionManager = FakePermissionManager(
        initialStatuses: {
          DevicePermission.accessibility: PermissionStatus.denied,
          DevicePermission.overlay: PermissionStatus.granted,
          DevicePermission.screenCapture: PermissionStatus.granted,
        },
      );
      validator = ActionValidator(permissionManager: permissionManager);

      final action = DeviceAction.tap(
        targetPoint: const NormalizedPoint(x: 0.5, y: 0.5),
      );
      final result = await validator.validate(action);
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull!.phase,
          DeviceIntegrationFailurePhase.permission);
    });

    test('permanentlyDenied permission is still denied', () async {
      permissionManager = FakePermissionManager(
        initialStatuses: {
          DevicePermission.accessibility: PermissionStatus.permanentlyDenied,
          DevicePermission.overlay: PermissionStatus.granted,
          DevicePermission.screenCapture: PermissionStatus.granted,
        },
      );
      validator = ActionValidator(permissionManager: permissionManager);

      final action = DeviceAction.back();
      final result = await validator.validate(action);
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull!.phase,
          DeviceIntegrationFailurePhase.permission);
    });
  });

  // ─── Static helpers ──────────────────────────────────────────────
  group('ActionValidator static helpers', () {
    test('checkSecurity allows safe action', () {
      final action = DeviceAction.tap(
        targetPoint: const NormalizedPoint(x: 0.5, y: 0.5),
        targetLabel: 'settings',
      );
      final verdict = ActionValidator.checkSecurity(action);
      expect(verdict.isAllowed, isTrue);
    });

    test('checkSecurity denies prohibited action', () {
      final action = DeviceAction.tap(
        targetPoint: const NormalizedPoint(x: 0.5, y: 0.5),
        targetLabel: 'hack',
      );
      final verdict = ActionValidator.checkSecurity(action);
      expect(verdict.isDenied, isTrue);
    });

    test('isProhibitedActionName returns correct results', () {
      expect(ActionValidator.isProhibitedActionName('auto_aim'), isTrue);
      expect(ActionValidator.isProhibitedActionName('tap'), isFalse);
    });
  });
}
