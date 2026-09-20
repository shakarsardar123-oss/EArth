// ───────────────────────────────────────────────────────────────────
// Step 16 – Central Permissions · Domain · CentralPermissionService
// ───────────────────────────────────────────────────────────────────
// Abstract interface for managing *all* AURA permissions through a
// single, centralized entry-point.
//
// This is a standalone abstract class (does NOT extend PermissionManager)
// because its method signatures are richer — they return
// CentralPermissionResult<T> instead of bare values.
//
// Full 5-step flow per permission:
//   check → explain → request → verify → settings (if permanentlyDenied)
// ───────────────────────────────────────────────────────────────────

import 'package:aura_assistant/features/device_integration/domain/models/permission_status.dart';
import 'package:aura_assistant/features/central_permissions/domain/models/central_permission_failure.dart';

/// High-level service for managing *all* AURA permissions through a
/// single, centralized entry-point.
///
/// Standalone abstract class with its own signatures that return
/// [CentralPermissionResult<T>] instead of bare values.
abstract class CentralPermissionService {
  /// Check the current status of a single permission.
  ///
  /// Returns [CentralPermissionResult] wrapping a [PermissionResult]
  /// with a single entry (use `.status` / `.permission` getters).
  Future<CentralPermissionResult<PermissionResult>> checkStatus(
    DevicePermission permission,
  );

  /// Request a single permission from the user.
  ///
  /// Returns [CentralPermissionResult] wrapping a [PermissionResult]
  /// with the final status after the system dialog.
  Future<CentralPermissionResult<PermissionResult>> requestPermission(
    DevicePermission permission,
  );

  /// Check the status of multiple permissions at once.
  ///
  /// Returns a map of [DevicePermission] → [PermissionStatus].
  Future<Map<DevicePermission, PermissionStatus>> checkAll(
    Iterable<DevicePermission> permissions,
  );

  /// Request multiple permissions at once.
  ///
  /// Returns a map of [DevicePermission] → the
  /// [CentralPermissionResult<PermissionResult>] for each individual
  /// request.  The caller decides what to do with failures.
  Future<Map<DevicePermission, CentralPermissionResult<PermissionResult>>>
      requestAll(
    Iterable<DevicePermission> permissions,
  );

  /// Whether the system recommends showing a rationale before
  /// requesting [permission].
  Future<bool> shouldShowRationale(DevicePermission permission);

  /// Open the system settings page for the given permission.
  ///
  /// Typically used when the permission is permanently denied and
  /// the user must manually grant it in Settings.
  Future<CentralPermissionResult<void>> openSettings(
    DevicePermission permission,
  );

  /// Which permissions are required for a given feature?
  ///
  /// Example: `'voice_screen'` → `[DevicePermission.microphone]`.
  List<DevicePermission> permissionsForFeature(String featureName);

  /// The inverse of [permissionsForFeature]: for a given permission,
  /// which features require it?
  List<String> featuresRequiringPermission(DevicePermission permission);
}
