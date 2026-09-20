/// central_permission_service_test.dart
/// AURA Assistant – Step 16: Central Permissions
///
/// Tests for CentralPermissionService abstract interface.

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/central_permissions/domain/central_permission_service.dart';
import 'package:aura_assistant/features/central_permissions/infrastructure/stub_central_permission_manager.dart';
import 'package:aura_assistant/features/device_integration/domain/models/permission_status.dart';
import 'package:aura_assistant/core/errors/result.dart';

/// Concrete test implementation of CentralPermissionService
/// that delegates to StubCentralPermissionManager.
class TestCentralPermissionService implements CentralPermissionService {
  final StubCentralPermissionManager _manager = StubCentralPermissionManager();

  @override
  Future<CentralPermissionResult<PermissionResult>> checkStatus(
    DevicePermission permission,
  ) => _manager.checkStatus(permission);

  @override
  Future<CentralPermissionResult<PermissionResult>> requestPermission(
    DevicePermission permission,
  ) => _manager.requestPermission(permission);

  @override
  Future<Map<DevicePermission, PermissionStatus>> checkAll(
    List<DevicePermission> permissions,
  ) => _manager.checkAll(permissions);

  @override
  Future<Map<DevicePermission, CentralPermissionResult<PermissionResult>>>
      requestAll(List<DevicePermission> permissions) =>
          _manager.requestAll(permissions);

  @override
  Future<bool> shouldShowRationale(DevicePermission permission) =>
      _manager.shouldShowRationale(permission);

  @override
  Future<CentralPermissionResult<void>> openSettings(
    DevicePermission permission,
  ) => _manager.openSettings(permission);

  @override
  List<DevicePermission> permissionsForFeature(String featureName) =>
      _manager.permissionsForFeature(featureName);

  @override
  List<String> featuresRequiringPermission(DevicePermission permission) =>
      _manager.featuresRequiringPermission(permission);
}

void main() {
  group('CentralPermissionService', () {
    late TestCentralPermissionService service;

    setUp(() {
      service = TestCentralPermissionService();
    });

    test('checkStatus delegates correctly', () async {
      final result = await service.checkStatus(DevicePermission.microphone);
      expect(result.isSuccess, true);
      expect(result.valueOrNull!.status, PermissionStatus.denied);
    });

    test('requestPermission delegates correctly', () async {
      final result = await service.requestPermission(DevicePermission.camera);
      expect(result.isSuccess, true);
      expect(result.valueOrNull!.status, PermissionStatus.denied);
    });

    test('checkAll returns map of statuses', () async {
      final result = await service.checkAll(DevicePermission.values);
      expect(result.length, 10);
    });

    test('requestAll returns map of results', () async {
      final result = await service.requestAll(DevicePermission.values);
      expect(result.length, 10);
    });

    test('openSettings returns result', () async {
      final result = await service.openSettings(DevicePermission.overlay);
      expect(result.isSuccess, true);
    });

    test('shouldShowRationale returns bool', () async {
      final result = await service.shouldShowRationale(DevicePermission.overlay);
      expect(result, isA<bool>());
    });

    test('permissionsForFeature returns list', () {
      final result = service.permissionsForFeature('voice_screen');
      expect(result, isA<List<DevicePermission>>());
    });

    test('featuresRequiringPermission returns list', () {
      final result = service.featuresRequiringPermission(DevicePermission.camera);
      expect(result, isA<List<String>>());
    });

    test('service never grants permissions via stub', () async {
      // Safety check: the service backed by stub must NEVER silently grant
      for (final perm in DevicePermission.values) {
        final check = await service.checkStatus(perm);
        expect(check.valueOrNull!.status, isNot(PermissionStatus.granted));
      }
    });
  });
}
