/// tool_permission_adapter.dart
/// AURA Assistant – Step 20: Tool Registry & Allowlist
///
/// Adapter that bridges Step 16's CentralPermissionService into the
/// Tool Registry's execution pipeline.
///
/// Translates tool's requiredPermissions (string identifiers) into
/// Step 16 permission checks.
library;

import 'package:aura_assistant/core/errors/result.dart';
import 'package:aura_assistant/features/tool_registry/domain/models/models.dart';

/// Permission check result for a tool execution.
class ToolPermissionResult {
  final bool allGranted;
  final List<String> granted;
  final List<String> denied;
  final List<String> notDetermined;

  const ToolPermissionResult({
    required this.allGranted,
    this.granted = const [],
    this.denied = const [],
    this.notDetermined = const [],
  });

  /// All permissions granted.
  factory ToolPermissionResult.allGranted(List<String> permissions) =>
      ToolPermissionResult(
        allGranted: true,
        granted: permissions,
      );

  /// Some permissions denied.
  factory ToolPermissionResult.someDenied({
    required List<String> granted,
    required List<String> denied,
    List<String>? notDetermined,
  }) =>
      ToolPermissionResult(
        allGranted: false,
        granted: granted,
        denied: denied,
        notDetermined: notDetermined ?? const [],
      );

  /// Fail-closed: permissions could not be determined.
  factory ToolPermissionResult.failClosed({
    required List<String> permissions,
    String? reason,
  }) =>
      ToolPermissionResult(
        allGranted: false,
        notDetermined: permissions,
      );

  /// FAIL CLOSED: any non-granted permission means execution is denied.
  bool get permitsExecution => allGranted;
}

/// Abstract interface for the permission adapter.
///
/// Bridges Step 16's CentralPermissionService so the tool
/// registry does not depend on it directly.
abstract class ToolPermissionAdapter {
  /// Check all required permissions for a tool.
  ///
  /// [toolId] – the tool being executed.
  /// [requiredPermissions] – string identifiers from ToolDefinition.
  ///
  /// Returns [ToolPermissionResult] indicating which permissions
  /// are granted/denied/not determined.
  /// FAIL CLOSED: if the permission service is unavailable,
  /// returns fail-closed (all permissions undetermined).
  Future<ToolPermissionResult> checkPermissions({
    required String toolId,
    required List<String> requiredPermissions,
  });

  /// Request permissions that are not yet granted.
  ///
  /// Returns the result of the permission request.
  Future<ToolPermissionResult> requestPermissions({
    required String toolId,
    required List<String> permissions,
  });

  /// Whether the permission service is currently available.
  bool get isAvailable;

  /// Check a single permission status.
  /// Returns 'granted', 'denied', 'notDetermined', or 'unknown'.
  Future<String> checkSinglePermission(String permissionId);
}

