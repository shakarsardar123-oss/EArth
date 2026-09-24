// ───────────────────────────────────────────────────────────────────
// Step 16 – Central Permissions · Application · Providers
// ───────────────────────────────────────────────────────────────────
// Follows the DeviceIntegrationProviderNames pattern:
//   abstract class with String name constants + typedefs.
// ───────────────────────────────────────────────────────────────────

import 'package:aura_assistant/features/central_permissions/domain/central_permission_service.dart';
import 'package:aura_assistant/features/central_permissions/application/central_permission_controller.dart';
import 'package:aura_assistant/features/central_permissions/application/central_permission_state.dart';

/// Provider name constants for the central_permissions feature module.
abstract class CentralPermissionProviderNames {
  // ── Names ────────────────────────────────────────────────────────

  static const String centralPermissionService =
      'centralPermissionService';
  static const String centralPermissionController =
      'centralPermissionController';
  static const String centralPermissionState =
      'centralPermissionState';

  // ── Typedefs ─────────────────────────────────────────────────────

  static const Type centralPermissionServiceType =
      CentralPermissionService;
  static const Type centralPermissionControllerType =
      CentralPermissionController;
  static const Type centralPermissionStateType =
      CentralPermissionState;

  // ── MethodChannel ────────────────────────────────────────────────

  static const String methodChannel =
      'com.aura.assistant/central_permissions';

  // Prevent instantiation.
  CentralPermissionProviderNames._();
}

/// Convenience typedefs matching the project pattern.
typedef CentralPermissionServiceProvider = CentralPermissionService;
typedef CentralPermissionControllerProvider = CentralPermissionController;
typedef CentralPermissionStateProvider = CentralPermissionState;
