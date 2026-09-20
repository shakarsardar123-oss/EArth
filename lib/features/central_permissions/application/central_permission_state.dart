// ───────────────────────────────────────────────────────────────────
// Step 16 – Central Permissions · Application · State
// ───────────────────────────────────────────────────────────────────
// Immutable state following the project convention (copyWith + clear*).
// ───────────────────────────────────────────────────────────────────

import 'package:aura_assistant/features/device_integration/domain/models/permission_status.dart';
import 'package:aura_assistant/features/central_permissions/domain/models/central_permission_failure.dart';

class CentralPermissionState {
  final Map<DevicePermission, PermissionStatus> statuses;
  final bool isLoading;
  final CentralPermissionFailure? failure;
  final DevicePermission? activePermission;

  const CentralPermissionState({
    this.statuses = const {},
    this.isLoading = false,
    this.failure,
    this.activePermission,
  });

  CentralPermissionState copyWith({
    Map<DevicePermission, PermissionStatus>? statuses,
    bool? isLoading,
    CentralPermissionFailure? failure,
    DevicePermission? activePermission,
    bool clearFailure = false,
    bool clearActivePermission = false,
  }) {
    return CentralPermissionState(
      statuses: statuses ?? this.statuses,
      isLoading: isLoading ?? this.isLoading,
      failure: clearFailure ? null : (failure ?? this.failure),
      activePermission: clearActivePermission
          ? null
          : (activePermission ?? this.activePermission),
    );
  }

  /// Convenience: is the given permission currently granted?
  bool isGranted(DevicePermission p) =>
      statuses[p] == PermissionStatus.granted;

  /// Convenience: is the given permission permanently denied?
  bool isPermanentlyDenied(DevicePermission p) =>
      statuses[p] == PermissionStatus.permanentlyDenied;

  /// All currently denied permissions.
  Iterable<DevicePermission> get deniedPermissions =>
      statuses.entries
          .where((e) => e.value != PermissionStatus.granted)
          .map((e) => e.key);

  /// All currently granted permissions.
  Iterable<DevicePermission> get grantedPermissions =>
      statuses.entries
          .where((e) => e.value == PermissionStatus.granted)
          .map((e) => e.key);

  /// Whether a failure is present.
  bool get hasFailure => failure != null;

  /// Whether all tracked permissions are granted.
  bool get allGranted =>
      statuses.isNotEmpty &&
      statuses.values.every((s) => s == PermissionStatus.granted);

  /// Whether any tracked permission is neither granted nor not-requested.
  bool get someDenied =>
      statuses.values.any(
          (s) => s != PermissionStatus.granted && s != PermissionStatus.notRequested);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CentralPermissionState &&
          _mapEquals(statuses, other.statuses) &&
          isLoading == other.isLoading &&
          failure == other.failure &&
          activePermission == other.activePermission;

  @override
  int get hashCode => Object.hash(
        Object.hashAllUnordered(statuses.entries),
        isLoading,
        failure,
        activePermission,
      );

  @override
  String toString() =>
      'CentralPermissionState(granted: ${grantedPermissions.length}, '
      'denied: ${deniedPermissions.length}, loading: $isLoading)';
}

bool _mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
  if (a.length != b.length) return false;
  for (final key in a.keys) {
    if (a[key] != b[key]) return false;
  }
  return true;
}
