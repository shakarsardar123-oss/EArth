/// permission_result_test.dart
/// AURA Assistant – Step 16: Central Permissions
///
/// Tests for PermissionResult model and CentralPermissionResult type alias.

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/device_integration/domain/models/permission_status.dart';
import 'package:aura_assistant/features/central_permissions/domain/models/central_permission_failure.dart';
import 'package:aura_assistant/core/errors/result.dart';

void main() {
  group('PermissionResult', () {
    test('permission getter returns correct DevicePermission', () {
      final result = PermissionResult.single(
        permission: DevicePermission.camera,
        status: PermissionStatus.granted,
      );

      expect(result.permission, DevicePermission.camera);
    });

    test('status getter returns correct PermissionStatus', () {
      final result = PermissionResult.single(
        permission: DevicePermission.overlay,
        status: PermissionStatus.permanentlyDenied,
      );

      expect(result.status, PermissionStatus.permanentlyDenied);
    });

    test('handles all PermissionStatus values', () {
      for (final status in PermissionStatus.values) {
        final result = PermissionResult.single(
          permission: DevicePermission.microphone,
          status: status,
        );
        expect(result.status, status);
      }
    });

    test('handles all DevicePermission values', () {
      for (final perm in DevicePermission.values) {
        final result = PermissionResult.single(
          permission: perm,
          status: PermissionStatus.notRequested,
        );
        expect(result.permission, perm);
      }
    });
  });

  group('CentralPermissionResult<T>', () {
    test('success case wraps value', () {
      final result = Result<String, CentralPermissionFailure>.success('ok');
      expect(result.isSuccess, true);
      expect(result.isFailure, false);
      expect(result.valueOrNull, 'ok');
    });

    test('failure case wraps CentralPermissionFailure', () {
      final failure = CentralPermissionFailure.unknown(
        message: 'test',
        action: 'test_action',
        cause: null,
      );
      final result = Result<String, CentralPermissionFailure>.failure(failure);
      expect(result.isSuccess, false);
      expect(result.isFailure, true);
      expect(result.failureOrNull, failure);
      expect(result.valueOrNull, isNull);
    });

    test('fold delegates to correct callback', () {
      final success = Result<int, CentralPermissionFailure>.success(42);
      final failure = Result<int, CentralPermissionFailure>.failure(
        CentralPermissionFailure.check(
          permission: DevicePermission.camera,
          action: 'retry_check',
          cause: null,
        ),
      );

      expect(
        success.fold(onSuccess: (v) => 's:$v', onFailure: (f) => 'f:${f.message}'),
        's:42',
      );
      // Failure path: CentralPermissionFailure auto-generates .message
      expect(
        failure.fold(onSuccess: (v) => 's:$v', onFailure: (f) => 'f:${f.message}'),
        contains('check'),
      );
    });
  });
}
