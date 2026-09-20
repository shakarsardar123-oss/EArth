/// Permission levels required by tools.
enum ToolPermission {
  /// No special permission required.
  none,

  /// Microphone access for voice input.
  microphone,

  /// Camera access.
  camera,

  /// File system / storage access.
  storage,

  /// Network / internet access.
  network,

  /// Location access.
  location,

  /// Notification permission.
  notifications,

  /// Contacts access.
  contacts,

  /// Phone / call access.
  phone,

  /// Battery / power state access.
  battery,

  /// System-level access (rare, e.g. wake lock).
  system,

  /// Screen capture via MediaProjection.
  /// Requires user confirmation through the system projection dialog,
  /// not a standard permission_handler permission.
  screen_capture,

  /// System overlay window (SYSTEM_ALERT_WINDOW) for floating overlay.
  /// Requires the user to grant overlay permission via system settings
  /// on Android 6.0+.
  systemAlertWindow,
}

/// Describes the permission requirement for a tool.
class ToolPermissionRequirement {
  const ToolPermissionRequirement({
    required this.permission,
    this.isRequired = true,
    this.rationale,
  });

  final ToolPermission permission;
  final bool isRequired;
  final String? rationale;

  @override
  String toString() =>
      'ToolPermissionRequirement($permission, required: $isRequired)';
}
