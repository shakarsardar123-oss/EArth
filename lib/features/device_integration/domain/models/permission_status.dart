/// permission_status.dart
///
/// Permission vocabulary and the abstract permission-manager contract for the
/// `device_integration` feature.
///
/// RECOVERED in P1-RECOVERY step R2 from the behaviour pinned by
/// `test/features/device_integration/permission_manager_test.dart`.
///
/// STEP 5 – Extended DevicePermission enum with ALL AURA permissions
/// (microphone, camera, notification, storage, batteryOptimization,
///  assistant, location, exactAlarm) plus PermissionResult.single
///  factory and .status / .permission convenience getters.
library;

import '../../../../core/errors/result.dart';
import 'device_integration_failure.dart';

/// Lifecycle state of a single permission.
enum PermissionStatus {
  /// The permission has never been asked for.
  notRequested,

  /// The user granted the permission.
  granted,

  /// The user refused, but may be asked again.
  denied,

  /// The user refused permanently; only the system settings screen can change
  /// this.
  permanentlyDenied,

  /// The status could not be determined (platform error, unsupported).
  unknown,
}

/// All device capabilities AURA may need permission for.
///
/// The original enum had only [accessibility], [overlay], [screenCapture]
/// for the device_integration feature.  Step 5 extends it to cover
/// microphone, camera, notification, storage, batteryOptimization,
/// assistant, location, and exactAlarm — the full set referenced by
/// central_permissions adapters and PlatformPermissionManager.
enum DevicePermission {
  /// Accessibility service — required to dispatch input events.
  accessibility,

  /// "Draw over other apps" — required for the floating overlay.
  overlay,

  /// Screen capture / media projection — required to read the screen.
  screenCapture,

  /// Microphone — required for voice recognition and speech input.
  microphone,

  /// Camera — required for vision / image analysis.
  camera,

  /// Notification — required to show local notifications (Android 13+).
  notification,

  /// External storage — required for file I/O.
  storage,

  /// Battery optimization exemption — required for foreground service.
  batteryOptimization,

  /// Default assistant — required for assistant integration.
  assistant,

  /// Location — required for location-based features.
  location,

  /// Exact alarm — required for scheduling precise alarms (Android 12+).
  exactAlarm,
}

/// The outcome of checking or requesting a set of permissions.
class PermissionResult {
  const PermissionResult({required this.statuses});

  /// Convenience factory for a single-permission result.
  ///
  /// Used by [CentralPermissionService.checkStatus] and
  /// [CentralPermissionService.requestPermission].
  factory PermissionResult.single({
    required DevicePermission permission,
    required PermissionStatus status,
  }) {
    return PermissionResult(statuses: {permission: status});
  }

  /// Status per requested permission.
  final Map<DevicePermission, PermissionStatus> statuses;

  /// True only when every requested permission is [PermissionStatus.granted].
  bool get allGranted =>
      statuses.isNotEmpty &&
      statuses.values.every((s) => s == PermissionStatus.granted);

  /// Permissions the user actively refused.
  ///
  /// [PermissionStatus.notRequested] is intentionally *not* counted as denied:
  /// nothing has been refused yet, it simply has not been asked.
  List<DevicePermission> get denied => statuses.entries
      .where((e) =>
          e.value == PermissionStatus.denied ||
          e.value == PermissionStatus.permanentlyDenied,)
      .map((e) => e.key)
      .toList(growable: false);

  /// Whether at least one permission is permanently denied, meaning the user
  /// must be sent to the system settings screen.
  bool get hasPermanentlyDenied =>
      statuses.values.any((s) => s == PermissionStatus.permanentlyDenied);

  // ── Single-result convenience getters ─────────────────────────────
  // Used by CentralPermissionController when it unwraps a
  // CentralPermissionResult<PermissionResult> for a single permission.

  /// The status of the single permission, or [PermissionStatus.unknown]
  /// if the result contains multiple entries.
  PermissionStatus get status =>
      statuses.length == 1 ? statuses.values.first : PermissionStatus.unknown;

  /// The single permission, or null if the result contains multiple entries.
  DevicePermission? get permission =>
      statuses.length == 1 ? statuses.keys.first : null;

  @override
  String toString() => 'PermissionResult($statuses)';
}

/// Contract for querying and requesting device permissions.
///
/// Implementations must be fail-closed: when the real platform state cannot be
/// determined they report a non-granted status rather than assuming success.
abstract class PermissionManager {
  /// Current status of a single permission.
  Future<PermissionStatus> checkStatus(DevicePermission permission);

  /// Prompts the user for [permissions] and reports the resulting statuses.
  Future<PermissionResult> request(Iterable<DevicePermission> permissions);

  /// Current status of every permission the feature can use, without prompting.
  Future<PermissionResult> checkAll();

  /// Prompts the user for every permission the feature can use.
  Future<PermissionResult> requestAll();

  /// Opens the system settings page for this app.
  ///
  /// Fails with a [DeviceIntegrationFailure] in the permission phase when the
  /// settings screen cannot be opened.
  Future<Result<void, DeviceIntegrationFailure>> openSettings();
}
