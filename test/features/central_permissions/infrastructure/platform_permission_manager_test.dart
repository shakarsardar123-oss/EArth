/// platform_permission_manager_test.dart
/// AURA Assistant – Step 16: Central Permissions
///
/// Tests for StubCentralPermissionManager (implements CentralPermissionService).

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/central_permissions/infrastructure/stub_central_permission_manager.dart';
import 'package:aura_assistant/features/device_integration/domain/models/permission_status.dart';

void main() {
  group('StubCentralPermissionManager', () {
    test('checkStatus returns CentralPermissionResult<PermissionResult>', () async {
      final manager = StubCentralPermissionManager();
      final result = await manager.checkStatus(DevicePermission.microphone);

      expect(result.isSuccess, true);
      final pr = result.valueOrNull!;
      expect(pr.status, PermissionStatus.denied);
    });

    test('requestPermission returns CentralPermissionResult<PermissionResult>', () async {
      final manager = StubCentralPermissionManager();
      final result = await manager.requestPermission(DevicePermission.camera);

      // Stub defaults autoGrantOnRequest=false → always returns denied
      expect(result.isSuccess, true);
      final pr = result.valueOrNull!;
      expect(pr.status, PermissionStatus.denied);
    });

    test('checkAll returns map of all 10 permissions', () async {
      final manager = StubCentralPermissionManager();
      final result = await manager.checkAll(DevicePermission.values);

      expect(result.length, DevicePermission.values.length);

      for (final perm in DevicePermission.values) {
        expect(result.containsKey(perm), true);
        expect(result[perm], PermissionStatus.denied);
      }
    });

    test('requestAll returns map of all 10 permissions', () async {
      final manager = StubCentralPermissionManager();
      final result = await manager.requestAll(DevicePermission.values);

      expect(result.length, DevicePermission.values.length);

      for (final perm in DevicePermission.values) {
        expect(result.containsKey(perm), true);
        // Stub never auto-grants
        expect(result[perm].isSuccess, true);
        expect(result[perm].valueOrNull!.status, PermissionStatus.denied);
      }
    });

    test('openSettings returns CentralPermissionResult<void>', () async {
      final manager = StubCentralPermissionManager();
      final result = await manager.openSettings(DevicePermission.overlay);

      expect(result.isSuccess, true);
    });

    test('shouldShowRationale returns bool', () async {
      final manager = StubCentralPermissionManager();
      final result = await manager.shouldShowRationale(DevicePermission.overlay);

      expect(result, isA<bool>());
    });

    test('permissionsForFeature returns list of DevicePermission', () {
      final manager = StubCentralPermissionManager();
      final perms = manager.permissionsForFeature('voice_screen');
      expect(perms, isA<List<DevicePermission>>());
      expect(perms, contains(DevicePermission.microphone));
    });

    test('featuresRequiringPermission returns list of strings', () {
      final manager = StubCentralPermissionManager();
      final features = manager.featuresRequiringPermission(DevicePermission.camera);
      expect(features, isA<List<String>>());
    });

    test('stub never returns granted status (never fakes permissions)', () async {
      final manager = StubCentralPermissionManager();

      for (final perm in DevicePermission.values) {
        final checkResult = await manager.checkStatus(perm);
        final reqResult = await manager.requestPermission(perm);

        // Stub MUST never return granted — that would be faking
        expect(checkResult.valueOrNull!.status, isNot(PermissionStatus.granted));
        expect(reqResult.valueOrNull!.status, isNot(PermissionStatus.granted));
      }
    });
  });
}
