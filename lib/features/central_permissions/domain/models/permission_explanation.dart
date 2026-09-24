// ───────────────────────────────────────────────────────────────────
// Step 16 – Central Permissions · Domain · PermissionExplanation
// ───────────────────────────────────────────────────────────────────
// Immutable value-object describing *why* a permission is needed,
// shown to the user before the system request dialog.
// ───────────────────────────────────────────────────────────────────

import 'package:texo/features/device_integration/domain/models/permission_status.dart';

/// Explains why a [DevicePermission] is required before requesting it.
///
/// Follows the pattern from [DeviceIntegrationFailure] – immutable,
/// self-contained, serializable.
class PermissionExplanation {
  final DevicePermission permission;
  final String titleKey;
  final String bodyKey;
  final String featureName;
  final bool isCritical;

  const PermissionExplanation({
    required this.permission,
    required this.titleKey,
    required this.bodyKey,
    required this.featureName,
    this.isCritical = false,
  });

  /// Pre-built explanations for every [DevicePermission].
  static final Map<DevicePermission, PermissionExplanation> defaults =
      Map.unmodifiable({
    DevicePermission.accessibility: PermissionExplanation(
      permission: DevicePermission.accessibility,
      titleKey: 'perm_accessibility_title',
      bodyKey: 'perm_accessibility_body',
      featureName: 'device_integration',
      isCritical: true,
    ),
    DevicePermission.overlay: PermissionExplanation(
      permission: DevicePermission.overlay,
      titleKey: 'perm_overlay_title',
      bodyKey: 'perm_overlay_body',
      featureName: 'floating_overlay',
      isCritical: true,
    ),
    DevicePermission.screenCapture: PermissionExplanation(
      permission: DevicePermission.screenCapture,
      titleKey: 'perm_screen_capture_title',
      bodyKey: 'perm_screen_capture_body',
      featureName: 'screen_capture',
      isCritical: true,
    ),
    DevicePermission.microphone: PermissionExplanation(
      permission: DevicePermission.microphone,
      titleKey: 'perm_microphone_title',
      bodyKey: 'perm_microphone_body',
      featureName: 'voice_screen',
      isCritical: true,
    ),
    DevicePermission.camera: PermissionExplanation(
      permission: DevicePermission.camera,
      titleKey: 'perm_camera_title',
      bodyKey: 'perm_camera_body',
      featureName: 'vision',
      isCritical: false,
    ),
    // RESTORED: storage now displayed as "Files & Media" in UI.
    // Uses granular READ_MEDIA_* on API 33+, READ_EXTERNAL_STORAGE on ≤32.
    DevicePermission.storage: PermissionExplanation(
      permission: DevicePermission.storage,
      titleKey: 'perm_storage_title',
      bodyKey: 'perm_storage_body',
      featureName: 'file_storage',
      isCritical: false,
    ),
    DevicePermission.notification: PermissionExplanation(
      permission: DevicePermission.notification,
      titleKey: 'perm_notification_title',
      bodyKey: 'perm_notification_body',
      featureName: 'notifications',
      isCritical: false,
    ),
    DevicePermission.batteryOptimization: PermissionExplanation(
      permission: DevicePermission.batteryOptimization,
      titleKey: 'perm_battery_title',
      bodyKey: 'perm_battery_body',
      featureName: 'foreground_service',
      isCritical: true,
    ),
    DevicePermission.assistant: PermissionExplanation(
      permission: DevicePermission.assistant,
      titleKey: 'perm_assistant_title',
      bodyKey: 'perm_assistant_body',
      featureName: 'assistant_integration',
      isCritical: true,
    ),
    // RESTORED: location needed by NavigationTool, MemoryType.location,
    //   system_settings_tool location action, SensitiveDataCategoryBridge.
    DevicePermission.location: PermissionExplanation(
      permission: DevicePermission.location,
      titleKey: 'perm_location_title',
      bodyKey: 'perm_location_body',
      featureName: 'location_services',
      isCritical: false,
    ),
    DevicePermission.exactAlarm: PermissionExplanation(
      permission: DevicePermission.exactAlarm,
      titleKey: 'perm_exact_alarm_title',
      bodyKey: 'perm_exact_alarm_body',
      featureName: 'exact_alarm',
      isCritical: true,
    ),
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PermissionExplanation &&
          permission == other.permission &&
          titleKey == other.titleKey &&
          bodyKey == other.bodyKey &&
          featureName == other.featureName &&
          isCritical == other.isCritical;

  @override
  int get hashCode => Object.hash(
        permission,
        titleKey,
        bodyKey,
        featureName,
        isCritical,
      );

  @override
  String toString() =>
      'PermissionExplanation(permission: $permission, '
      'feature: $featureName, critical: $isCritical)';
}
