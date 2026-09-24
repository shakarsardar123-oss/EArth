// ───────────────────────────────────────────────────────────────────
// Step 16 – Central Permissions · Infrastructure · Stub
// ───────────────────────────────────────────────────────────────────
// In-memory stub for testing. Modeled after StubPermissionManager.
//
// ⚠️  The [autoGrantOnRequest] flag exists ONLY for testing – the
//     real implementation MUST NEVER auto-grant. In production code
//     use [PlatformPermissionManager] instead.
// ───────────────────────────────────────────────────────────────────

import 'package:texo/core/errors/result.dart';
import 'package:texo/features/device_integration/domain/models/permission_status.dart';
import 'package:texo/features/central_permissions/domain/central_permission_service.dart';
import 'package:texo/features/central_permissions/domain/models/central_permission_failure.dart';

class StubCentralPermissionManager extends CentralPermissionService {
  /// When true, requestPermission always returns granted.
  /// ⚠️  FOR TESTING ONLY – never use in production.
  bool autoGrantOnRequest;

  final Map<DevicePermission, PermissionStatus> _statuses;
  final Map<DevicePermission, bool> _rationaleFlags;

  StubCentralPermissionManager({
    this.autoGrantOnRequest = false,
    Map<DevicePermission, PermissionStatus>? initialStatuses,
    Map<DevicePermission, bool>? initialRationaleFlags,
  })  : _statuses = Map<DevicePermission, PermissionStatus>.from(
          initialStatuses ??
              {
                for (final p in DevicePermission.values)
                  p: PermissionStatus.denied,
              },
        ),
        _rationaleFlags = Map<DevicePermission, bool>.from(
          initialRationaleFlags ??
              {
                for (final p in DevicePermission.values) p: false,
              },
        );

  // ── Test helpers ─────────────────────────────────────────────────

  void setStatus(
    DevicePermission permission,
    PermissionStatus status,
  ) {
    _statuses[permission] = status;
  }

  void setRationale(DevicePermission permission, bool show) {
    _rationaleFlags[permission] = show;
  }

  // ── Feature mapping ─────────────────────────────────────────────

  static const Map<String, List<DevicePermission>> _featurePermissions = {
    'voice_screen': [DevicePermission.microphone],
    'vision': [DevicePermission.camera],
    'screen_capture': [DevicePermission.screenCapture],
    'floating_overlay': [DevicePermission.overlay],
    'assistant_integration': [DevicePermission.assistant],
    'device_integration': [
      DevicePermission.accessibility,
      DevicePermission.overlay,
      DevicePermission.screenCapture,
    ],
    'file_storage': [DevicePermission.storage],
    'notifications': [DevicePermission.notification],
    'foreground_service': [DevicePermission.batteryOptimization],
    'location_services': [DevicePermission.location],
    'exact_alarm': [DevicePermission.exactAlarm],
  };

  @override
  List<DevicePermission> permissionsForFeature(String featureName) =>
      _featurePermissions[featureName] ??
      [
        DevicePermission.values.firstWhere(
          (p) => p.name == featureName,
          orElse: () => DevicePermission.accessibility,
        )
      ];

  @override
  List<String> featuresRequiringPermission(DevicePermission permission) =>
      _featurePermissions.entries
          .where((e) => e.value.contains(permission))
          .map((e) => e.key)
          .toList();

  // ── Single-permission operations ────────────────────────────────

  @override
  Future<CentralPermissionResult<PermissionResult>> checkStatus(
    DevicePermission permission,
  ) async {
    final status = _statuses[permission] ?? PermissionStatus.unknown;
    return Result.success(
      PermissionResult.single(permission: permission, status: status),
    );
  }

  @override
  Future<CentralPermissionResult<PermissionResult>> requestPermission(
    DevicePermission permission,
  ) async {
    if (autoGrantOnRequest) {
      _statuses[permission] = PermissionStatus.granted;
      return Result.success(
        PermissionResult.single(
          permission: permission,
          status: PermissionStatus.granted,
        ),
      );
    }
    // Simulate user denying (first time) → can request again.
    _statuses[permission] = PermissionStatus.denied;
    _rationaleFlags[permission] = true; // denied once → rationale
    return Result.success(
      PermissionResult.single(
        permission: permission,
        status: PermissionStatus.denied,
      ),
    );
  }

  @override
  Future<bool> shouldShowRationale(DevicePermission permission) async {
    return _rationaleFlags[permission] ?? false;
  }

  @override
  Future<CentralPermissionResult<void>> openSettings(
    DevicePermission permission,
  ) async {
    // Stub: simulate settings open (no-op).
    return Result.success(null);
  }

  // ── Batch operations ────────────────────────────────────────────

  @override
  Future<Map<DevicePermission, PermissionStatus>> checkAll(
    Iterable<DevicePermission> permissions,
  ) async {
    return {
      for (final p in permissions)
        p: _statuses[p] ?? PermissionStatus.unknown,
    };
  }

  @override
  Future<Map<DevicePermission, CentralPermissionResult<PermissionResult>>>
      requestAll(
    Iterable<DevicePermission> permissions,
  ) async {
    final results =
        <DevicePermission, CentralPermissionResult<PermissionResult>>{};
    for (final p in permissions) {
      final r = await requestPermission(p);
      if (r.isSuccess) {
        results[p] = Result.success(r.valueOrNull!);
      } else {
        results[p] = Result.failure(
          CentralPermissionFailure.request(
            permission: p,
            status: PermissionStatus.denied,
          ),
        );
      }
    }
    return results;
  }
}
