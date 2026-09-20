/// feature_permission_adapter.dart
/// AURA Assistant – Step 16: Central Permissions
///
/// Abstract base for feature→permission adapters.
/// Each feature module that requires permissions implements this class
/// to declare which DevicePermission values it needs.

import 'package:aura_assistant/features/device_integration/domain/models/permission_status.dart';

/// Maps a feature module to the set of [DevicePermission] values it requires.
///
/// Features must NEVER silently grant or bypass permissions.
/// They declare their needs via this adapter; the CentralPermissionController
/// orchestrates the actual request flow.
abstract class FeaturePermissionAdapter {
  /// Unique name of the feature module this adapter represents.
  String get featureName;

  /// The list of [DevicePermission] values this feature requires
  /// to function correctly. Ordered by priority (most critical first).
  List<DevicePermission> get requiredPermissions;

  /// Optional: permissions that enhance the feature but are not strictly
  /// required. The feature may degrade gracefully without them.
  List<DevicePermission> get optionalPermissions => const [];

  /// Whether all [requiredPermissions] must be granted for the feature
  /// to activate, or if it can partially function.
  /// Defaults to true (all-or-nothing).
  bool get requiresAll => true;

  @override
  String toString() =>
      'FeaturePermissionAdapter($featureName, required: ${requiredPermissions.map((p) => p.name).join(", ")})';
}
