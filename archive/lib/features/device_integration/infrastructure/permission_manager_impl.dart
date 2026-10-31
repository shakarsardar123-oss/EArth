/// permission_manager_impl.dart
///
/// Stub permission manager for testing and non-production environments.
///
/// RECOVERED in P1-RECOVERY step R2 from the behaviour pinned by
/// `test/features/device_integration/permission_manager_impl_test.dart`.
///
/// DESIGN NOTE: [autoGrantOnRequest] defaults to `true` to allow tests to
/// run without platform permission prompts. In production, a real
/// implementation should *never* auto-grant; it should delegate to the
/// platform's permission dialog. The stub is isolated for test-only wiring.
library;

import '../domain/models/permission_status.dart';
import '../domain/models/device_integration_failure.dart';
import '../../../core/errors/result.dart';

/// A stub [PermissionManager] that allows tests to control permission
/// outcomes without platform side-effects.
///
/// **Not for production use.** A real implementation must delegate to the
/// Android/iOS permission system.
class StubPermissionManager implements PermissionManager {
  StubPermissionManager({
    this.autoGrantOnRequest = true,
    Map<DevicePermission, PermissionStatus>? initialStatuses,
  }) : _statuses = Map<DevicePermission, PermissionStatus>.from(
           initialStatuses ??
               {
                 for (final p in DevicePermission.values)
                   p: PermissionStatus.notRequested,
               },
         );

  /// When `true`, [request] and [requestAll] immediately grant every
  /// requested permission. When `false`, they deny every request.
  ///
  /// Defaults to `true` so that unit tests pass without platform prompts.
  final bool autoGrantOnRequest;

  final Map<DevicePermission, PermissionStatus> _statuses;

  /// Directly set a permission's status (test helper).
  void setStatus(DevicePermission permission, PermissionStatus status) {
    _statuses[permission] = status;
  }

  @override
  Future<PermissionStatus> checkStatus(DevicePermission permission) async =>
      _statuses[permission] ?? PermissionStatus.notRequested;

  @override
  Future<PermissionResult> request(
      Iterable<DevicePermission> permissions) async {
    final newStatuses = <DevicePermission, PermissionStatus>{};
    for (final p in permissions) {
      final status = autoGrantOnRequest
          ? PermissionStatus.granted
          : PermissionStatus.denied;
      _statuses[p] = status;
      newStatuses[p] = status;
    }
    return PermissionResult(statuses: newStatuses);
  }

  @override
  Future<PermissionResult> checkAll() async =>
      PermissionResult(statuses: Map.from(_statuses));

  @override
  Future<PermissionResult> requestAll() async =>
      request(DevicePermission.values);

  @override
  Future<Result<void, DeviceIntegrationFailure>> openSettings() async =>
      const Result.success(null);
}
