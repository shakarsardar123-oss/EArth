/// Permission status states for the AURA security system.
///
/// Represents the full lifecycle of an Android permission:
/// granted → can proceed, denied → may request again,
/// permanentlyDenied → must open settings, unsupported → graceful fallback.
library;

import 'package:meta/meta.dart' show immutable;

/// Status of a single permission check at runtime.
enum ToolPermissionStatus {
  /// Permission has been granted — tool may proceed.
  granted,

  /// Permission has been denied — may request again.
  denied,

  /// Permission permanently denied — user checked "Don't ask again".
  /// Must guide user to system settings to re-enable.
  permanentlyDenied,

  /// Permission is not available on this platform (non-Android).
  /// Tool should gracefully fall back or skip.
  unsupported;

  /// Whether this status allows tool execution.
  bool get isAllowed => this == ToolPermissionStatus.granted;

  /// Whether the user can still be prompted (denied but not permanent).
  bool get canRequest => this == ToolPermissionStatus.denied;

  /// Whether the tool should fall back gracefully.
  bool get shouldFallback =>
      this == ToolPermissionStatus.unsupported ||
      this == ToolPermissionStatus.permanentlyDenied;
}

/// Result of checking a tool's permission requirements.
///
/// Contains the overall status and per-permission breakdowns
/// so the security gate can make informed decisions.
@immutable
class PermissionCheckResult {
  const PermissionCheckResult({
    required this.overallStatus,
    required this.permissionStatuses,
    this.deniedPermissions = const [],
    this.permanentlyDeniedPermissions = const [],
    this.unsupportedPermissions = const [],
    this.messages = const [],
  });

  /// The aggregate status — the most restrictive among all checks.
  /// If any required permission is denied, overall is denied.
  final ToolPermissionStatus overallStatus;

  /// Per-permission status map (ToolPermission → ToolPermissionStatus).
  final Map<ToolPermissionStatus, List<String>> permissionStatuses;

  /// Permission names that are denied (can still request).
  final List<String> deniedPermissions;

  /// Permission names that are permanently denied.
  final List<String> permanentlyDeniedPermissions;

  /// Permission names that are unsupported on this platform.
  final List<String> unsupportedPermissions;

  /// Bilingual messages describing each status.
  final List<String> messages;

  /// Whether all required permissions are granted.
  bool get isAllGranted => overallStatus == ToolPermissionStatus.granted;

  /// Whether any required permission is permanently denied or unsupported.
  bool get needsGracefulFallback =>
      permanentlyDeniedPermissions.isNotEmpty ||
      unsupportedPermissions.isNotEmpty;

  /// Whether any permission can still be requested (denied but not permanent).
  bool get canRequestAny => deniedPermissions.isNotEmpty;

  @override
  String toString() =>
      'PermissionCheckResult(status: $overallStatus, denied: $deniedPermissions, '
      'permanent: $permanentlyDeniedPermissions, unsupported: $unsupportedPermissions)';
}
