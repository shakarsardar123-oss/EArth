/// permission_repository.dart
/// AURA Assistant – Step 25: Adapter target for Step 23 PermissionRepository
///
/// Exact signature match from Step 23.
library;

/// Represents a permission verdict.
class PermissionVerdict {
  final bool granted;
  final String? reason;

  const PermissionVerdict({
    this.granted = false,
    this.reason,
  });

  /// FAIL-CLOSED: default is not granted.
  bool get isGranted => granted;
}

/// Abstract repository matching Step 23's PermissionRepository.
/// check(permission, toolId) → PermissionVerdict
/// request(permission, toolId) → PermissionVerdict
/// isAvailable() → bool
abstract class PermissionRepository {
  Future<PermissionVerdict> check(String permission, String toolId);
  Future<PermissionVerdict> request(String permission, String toolId);
  bool isAvailable();
}
