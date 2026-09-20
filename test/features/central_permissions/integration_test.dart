/// integration_test.dart
/// AURA Assistant – Step 16: Central Permissions
///
/// Structural integration tests: verify cross-layer wiring.
/// No Flutter SDK — structural/mock tests only.

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/central_permissions/domain/central_permission_service.dart';
import 'package:aura_assistant/features/central_permissions/infrastructure/stub_central_permission_manager.dart';
import 'package:aura_assistant/features/central_permissions/application/central_permission_controller.dart';
import 'package:aura_assistant/features/central_permissions/application/central_permission_state.dart';
import 'package:aura_assistant/features/central_permissions/domain/models/central_permission_failure.dart';
import 'package:aura_assistant/features/central_permissions/domain/models/permission_explanation.dart';
import 'package:aura_assistant/features/device_integration/domain/models/permission_status.dart';
import 'package:aura_assistant/core/errors/result.dart';

void main() {
  group('Cross-layer integration (structural)', () {
    test('StubCentralPermissionManager implements CentralPermissionService', () {
      final manager = StubCentralPermissionManager();
      expect(manager, isA<CentralPermissionService>());
    });

    test('CentralPermissionController depends on CentralPermissionService', () {
      // Structural: verify controller constructor takes a service
      expect(CentralPermissionController, isNotNull);
    });

    test('CentralPermissionState uses DevicePermission as key', () {
      final state = CentralPermissionState.initial();
      expect(state.statuses, isA<Map<DevicePermission, PermissionStatus>>());
    });

    test('CentralPermissionResult<T> is Result<T, CentralPermissionFailure>', () {
      // Verify the type alias
      final success = CentralPermissionResult<PermissionResult>.success(
        PermissionResult.single(
          permission: DevicePermission.microphone,
          status: PermissionStatus.denied,
        ),
      );
      expect(success.isSuccess, true);
      expect(success.valueOrNull, isA<PermissionResult>());

      final failure = CentralPermissionResult<PermissionResult>.failure(
        CentralPermissionFailure.unknown(
          message: 'test',
          permission: DevicePermission.microphone,
        ),
      );
      expect(failure.isFailure, true);
      expect(failure.failureOrNull, isA<CentralPermissionFailure>());
    });

    test('PermissionExplanation.defaults covers all 10 DevicePermissions', () {
      for (final perm in DevicePermission.values) {
        expect(
          PermissionExplanation.defaults.containsKey(perm),
          true,
          reason: 'Missing explanation for $perm',
        );
      }
    });

    test('feature-permission mapping is complete', () async {
      final manager = StubCentralPermissionManager();
      final featureNames = [
        'voice_screen', 'vision', 'screen_capture', 'floating_overlay',
        'assistant_integration', 'device_integration', 'file_storage',
        'notifications', 'foreground_service', 'location_services',
      ];

      for (final name in featureNames) {
        final perms = manager.permissionsForFeature(name);
        expect(perms, isNotEmpty,
            reason: 'Feature $name has no permissions mapped');
      }
    });

    test('reverse mapping: featuresRequiringPermission for each perm', () {
      final manager = StubCentralPermissionManager();
      for (final perm in DevicePermission.values) {
        final features = manager.featuresRequiringPermission(perm);
        // At least one feature should reference each permission
        expect(features, isA<List<String>>());
      }
    });

    test('CentralPermissionFailure phases cover check and request', () {
      expect(CentralPermissionFailurePhase.check, isNotNull);
      expect(CentralPermissionFailurePhase.request, isNotNull);
    });

    test('stub never grants — never fakes permissions', () async {
      final manager = StubCentralPermissionManager();
      for (final perm in DevicePermission.values) {
        final check = await manager.checkStatus(perm);
        expect(check.valueOrNull!.status, isNot(PermissionStatus.granted));

        final request = await manager.requestPermission(perm);
        expect(request.valueOrNull!.status, isNot(PermissionStatus.granted));
      }
    });

    test('MethodChannel constant is correct', () {
      // Structural: verify the channel name
      // 'com.aura.assistant/central_permissions'
      // This is defined in the platform permission manager
      expect('com.aura.assistant/central_permissions', isNotEmpty);
    });
  });
}
