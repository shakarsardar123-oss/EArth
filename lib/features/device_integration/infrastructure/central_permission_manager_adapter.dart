import '../../../core/errors/result.dart';
import '../../central_permissions/domain/central_permission_service.dart';
import '../domain/models/device_integration_failure.dart';
import '../domain/models/permission_status.dart';

/// Bridges the centralized production permission service to the
/// device_integration PermissionManager contract.
///
/// Fail-closed: central permission failures never become "granted".
class CentralPermissionManagerAdapter implements PermissionManager {
  CentralPermissionManagerAdapter({
    required CentralPermissionService service,
  }) : _service = service;

  final CentralPermissionService _service;

  List<DevicePermission> get _requiredPermissions =>
      _service.permissionsForFeature('device_integration');

  @override
  Future<PermissionStatus> checkStatus(
    DevicePermission permission,
  ) async {
    final result = await _service.checkStatus(permission);

    if (result.isSuccess) {
      return result.valueOrNull?.status ?? PermissionStatus.unknown;
    }

    return PermissionStatus.unknown;
  }

  @override
  Future<PermissionResult> request(
    Iterable<DevicePermission> permissions,
  ) async {
    final requested = permissions.toList(growable: false);
    final results = await _service.requestAll(requested);

    final statuses = <DevicePermission, PermissionStatus>{};

    for (final permission in requested) {
      final result = results[permission];

      if (result == null || result.isFailure) {
        statuses[permission] = PermissionStatus.unknown;
      } else {
        statuses[permission] =
            result.valueOrNull?.status ?? PermissionStatus.unknown;
      }
    }

    return PermissionResult(statuses: statuses);
  }

  @override
  Future<PermissionResult> checkAll() async {
    final permissions = _requiredPermissions;
    final statuses = await _service.checkAll(permissions);

    return PermissionResult(
      statuses: {
        for (final permission in permissions)
          permission: statuses[permission] ?? PermissionStatus.unknown,
      },
    );
  }

  @override
  Future<PermissionResult> requestAll() {
    return request(_requiredPermissions);
  }

  @override
  Future<Result<void, DeviceIntegrationFailure>> openSettings() async {
    for (final permission in _requiredPermissions) {
      final result = await _service.openSettings(permission);

      if (result.isSuccess) {
        return Result.success(null);
      }
    }

    return Result.failure(
      const DeviceIntegrationFailure.permission(
        'Could not open permission settings.',
      ),
    );
  }
}
