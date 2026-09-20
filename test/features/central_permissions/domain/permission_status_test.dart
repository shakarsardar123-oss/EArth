/// permission_status_test.dart
/// AURA Assistant – Step 16: Central Permissions
///
/// Tests for PermissionStatus enum (5 values) and PermissionResult.

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/device_integration/domain/models/permission_status.dart';

void main() {
  group('PermissionStatus', () {
    test('has exactly 5 values', () {
      expect(PermissionStatus.values.length, 5);
    });

    test('contains all expected values', () {
      expect(PermissionStatus.values, containsAll([
        PermissionStatus.granted,
        PermissionStatus.denied,
        PermissionStatus.notRequested,
        PermissionStatus.permanentlyDenied,
        PermissionStatus.unknown,
      ]));
    });

    test('unknown is the 5th value', () {
      expect(PermissionStatus.unknown.name, 'unknown');
    });
  });

  group('PermissionResult', () {
    test('single() creates result with permission and status', () {
      final result = PermissionResult.single(
        permission: DevicePermission.microphone,
        status: PermissionStatus.granted,
      );

      expect(result.permission, DevicePermission.microphone);
      expect(result.status, PermissionStatus.granted);
    });

    test('single() with denied status', () {
      final result = PermissionResult.single(
        permission: DevicePermission.camera,
        status: PermissionStatus.denied,
      );

      expect(result.permission, DevicePermission.camera);
      expect(result.status, PermissionStatus.denied);
    });

    test('single() with unknown status', () {
      final result = PermissionResult.single(
        permission: DevicePermission.location,
        status: PermissionStatus.unknown,
      );

      expect(result.permission, DevicePermission.location);
      expect(result.status, PermissionStatus.unknown);
    });
  });
}
