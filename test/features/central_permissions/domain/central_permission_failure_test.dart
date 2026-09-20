/// central_permission_failure_test.dart
/// AURA Assistant – Step 16: Central Permissions
///
/// Tests for CentralPermissionFailure domain model.

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/central_permissions/domain/models/central_permission_failure.dart';
import 'package:aura_assistant/features/device_integration/domain/models/permission_status.dart';

void main() {
  group('CentralPermissionFailurePhase', () {
    test('phase enum has all 6 values', () {
      expect(CentralPermissionFailurePhase.values.length, 6);
      expect(CentralPermissionFailurePhase.values, containsAll([
        CentralPermissionFailurePhase.check,
        CentralPermissionFailurePhase.explanation,
        CentralPermissionFailurePhase.request,
        CentralPermissionFailurePhase.verify,
        CentralPermissionFailurePhase.settings,
        CentralPermissionFailurePhase.unknown,
      ]));
    });
  });

  group('CentralPermissionFailure', () {
    test('check factory creates failure with check phase', () {
      final failure = CentralPermissionFailure.check(
        permission: DevicePermission.camera,
        action: 'retry_check',
        cause: null,
      );

      expect(failure.phase, CentralPermissionFailurePhase.check);
      expect(failure.message, isNotEmpty);
    });

    test('explanation factory creates failure with explanation phase', () {
      final failure = CentralPermissionFailure.explanation(
        permission: DevicePermission.microphone,
        action: 'show_rationale',
        cause: null,
      );

      expect(failure.phase, CentralPermissionFailurePhase.explanation);
      expect(failure.message, isNotEmpty);
    });

    test('request factory creates failure with request phase', () {
      final failure = CentralPermissionFailure.request(
        permission: DevicePermission.overlay,
        status: PermissionStatus.denied,
        action: 'retry_request',
        cause: null,
      );

      expect(failure.phase, CentralPermissionFailurePhase.request);
      expect(failure.message, isNotEmpty);
    });

    test('verify factory creates failure with verify phase', () {
      final failure = CentralPermissionFailure.verify(
        permission: DevicePermission.location,
        status: PermissionStatus.permanentlyDenied,
        action: 'recheck',
        cause: null,
      );

      expect(failure.phase, CentralPermissionFailurePhase.verify);
      expect(failure.message, isNotEmpty);
    });

    test('settings factory creates failure with settings phase', () {
      final failure = CentralPermissionFailure.settings(
        permission: DevicePermission.notification,
        action: 'open_settings_manually',
        cause: null,
      );

      expect(failure.phase, CentralPermissionFailurePhase.settings);
      expect(failure.message, isNotEmpty);
    });

    test('unknown factory creates failure with unknown phase', () {
      final failure = CentralPermissionFailure.unknown(
        message: 'Unexpected platform error',
        action: 'unknown',
        cause: null,
      );

      expect(failure.phase, CentralPermissionFailurePhase.unknown);
      expect(failure.message, contains('Unexpected platform error'));
    });

    test('toString includes phase and message', () {
      final failure = CentralPermissionFailure.unknown(
        message: 'test error',
        action: 'test',
        cause: null,
      );

      expect(failure.toString(), contains('unknown'));
      expect(failure.toString(), contains('test error'));
    });

    test('no platform factory exists — only 6 valid phases', () {
      // Ensure there is no .platform() factory; only the 6 listed phases exist.
      // This is a structural assertion — the absence of CentralPermissionFailurePhase.platform
      // confirms the API does not expose it.
      expect(
        CentralPermissionFailurePhase.values
            .where((p) => p.name == 'platform'),
        isEmpty,
      );
    });
  });
}
