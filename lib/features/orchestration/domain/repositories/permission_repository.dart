/// Step 23 — Permission Repository Interface
///
/// Contract for the Step 16 Permission adapter.
/// FAIL-CLOSED: unknown/unchecked permissions → denied.
/// Never fake permission success.

abstract class PermissionRepository {
  /// Check if the required permission is granted.
  /// Returns PermissionVerdict. Default/unknown = denied.
  Future<PermissionVerdict> check(String permission, String toolId);

  /// Request a permission from the user (runtime flow).
  /// Returns the verdict after the request.
  Future<PermissionVerdict> request(String permission, String toolId);

  /// Whether the permission subsystem is available.
  Future<bool> isAvailable();
}

/// Permission verdict — FAIL-CLOSED by default.
class PermissionVerdict {
  final bool granted;
  final String? reason;
  final bool shouldOpenSettings;

  const PermissionVerdict({
    this.granted = false,
    this.reason,
    this.shouldOpenSettings = false,
  });

  factory PermissionVerdict.denied({String? reason, bool shouldOpenSettings = false}) =>
      PermissionVerdict(granted: false, reason: reason, shouldOpenSettings: shouldOpenSettings);

  factory PermissionVerdict.granted() =>
      const PermissionVerdict(granted: true);
}
