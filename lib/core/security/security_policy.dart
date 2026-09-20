/// Security policy mapping for the AURA tool framework.
///
/// Maps [ToolPermission] values to Android permission_handler [Permission] objects,
/// defines sensitive action registries, and provides dynamic risk elevation rules.
library;

import 'package:permission_handler/permission_handler.dart' as ph;
import '../tools/tool_permission.dart';
import '../agent/agent_confirmation_manager.dart';

/// Maps each [ToolPermission] to its Android permission_handler equivalent.
///
/// Tools declare permissions as [ToolPermission] enums (platform-agnostic).
/// This policy translates them to actual Android [ph.Permission] objects
/// at runtime. Permissions not relevant on the current platform map to null.
final Map<ToolPermission, ph.Permission?> securityPolicyPermissionMap = {
  ToolPermission.none: null,
  ToolPermission.microphone: ph.Permission.microphone,
  ToolPermission.camera: ph.Permission.camera,
  ToolPermission.storage: ph.Permission.storage,
  ToolPermission.network: null, // network is implicit on Android
  ToolPermission.location: ph.Permission.location,
  ToolPermission.notifications: ph.Permission.notification,
  ToolPermission.contacts: ph.Permission.contacts,
  ToolPermission.phone: ph.Permission.phone,
  ToolPermission.battery: null, // battery info needs no explicit permission
  ToolPermission.system: ph.Permission.accessNotificationPolicy,
  // screen_capture uses Android MediaProjection, which is not a standard
  // permission_handler permission. Permission is obtained via the
  // MediaProjection system dialog at capture time, handled by
  // ScreenCaptureService through platform channels.
  ToolPermission.screen_capture: null,

  // systemAlertWindow requires SYSTEM_ALERT_WINDOW permission.
  // On Android 6.0+ this requires the user to navigate to system
  // overlay settings and grant the permission manually.
  ToolPermission.systemAlertWindow: ph.Permission.systemAlertWindow,
};

/// Sensitive settings keys that require elevated risk levels.
///
/// When SystemSettingsTool encounters these keys, its risk level is
/// dynamically elevated from the default to the mapped level.
const Map<String, ToolRiskLevel> sensitiveSettingsKeys = {
  'security': ToolRiskLevel.critical,
  'location': ToolRiskLevel.high,
  'privacy': ToolRiskLevel.high,
  'accessibility': ToolRiskLevel.critical,
  'developer': ToolRiskLevel.high,
  'usb_debugging': ToolRiskLevel.critical,
  'install_unknown_apps': ToolRiskLevel.critical,
  'device_admin': ToolRiskLevel.critical,
  'vpn': ToolRiskLevel.high,
  'credential_storage': ToolRiskLevel.critical,
};

/// Sensitive URL protocols that require confirmation before launching.
const Set<String> sensitiveUrlProtocols = {
  'tel',
  'sms',
  'mailto',
  'market',
};

/// Sensitive app package prefixes that require elevated risk.
const Set<String> sensitivePackagePrefixes = {
  'com.android.settings',
  'com.android.security',
  'com.android.vpn',
  'com.android.credentials',
};

/// Central security policy for the AURA tool framework.
///
/// Provides:
/// - [ToolPermission] → [ph.Permission] mapping
/// - Sensitive action registries (settings keys, URL protocols, package prefixes)
/// - Dynamic risk elevation rules
/// - Security boundary validation
class SecurityPolicy {
  SecurityPolicy({
    Map<ToolPermission, ph.Permission?>? permissionMap,
    Map<String, ToolRiskLevel>? sensitiveSettings,
    Set<String>? sensitiveProtocols,
    Set<String>? sensitivePackages,
  })  : permissionMap = permissionMap ?? securityPolicyPermissionMap,
        sensitiveSettings = sensitiveSettings ?? sensitiveSettingsKeys,
        sensitiveProtocols = sensitiveProtocols ?? sensitiveUrlProtocols,
        sensitivePackages = sensitivePackages ?? sensitivePackagePrefixes;

  /// Mapping from ToolPermission to Android permission_handler Permission.
  final Map<ToolPermission, ph.Permission?> permissionMap;

  /// Sensitive settings keys and their required risk levels.
  final Map<String, ToolRiskLevel> sensitiveSettings;

  /// URL protocols considered sensitive (require confirmation).
  final Set<String> sensitiveProtocols;

  /// App package prefixes considered sensitive.
  final Set<String> sensitivePackages;

  /// Resolves a [ToolPermission] to its Android [ph.Permission].
  ///
  /// Returns null if the permission is not applicable on this platform
  /// (e.g., network, battery, or none).
  ph.Permission? resolvePermission(ToolPermission permission) {
    return permissionMap[permission];
  }

  /// Returns all [ph.Permission] objects required by a tool.
  ///
  /// Filters out null entries (permissions that need no Android request).
  List<ph.Permission> resolvePermissions(
      List<ToolPermissionRequirement> requirements) {
    final permissions = <ph.Permission>[];
    for (final req in requirements) {
      if (req.isRequired) {
        final resolved = resolvePermission(req.permission);
        if (resolved != null) {
          permissions.add(resolved);
        }
      }
    }
    return permissions;
  }

  /// Determines the effective risk level for a system settings action.
  ///
  /// If the [settingsKey] matches a sensitive key, returns its elevated level.
  /// Otherwise returns the tool's [defaultRisk].
  ToolRiskLevel elevatedRiskForSettingsKey(
    String settingsKey,
    ToolRiskLevel defaultRisk,
  ) {
    final key = settingsKey.toLowerCase();
    if (sensitiveSettings.containsKey(key)) {
      return sensitiveSettings[key]!;
    }
    return defaultRisk;
  }

  /// Whether a URL protocol is considered sensitive.
  bool isSensitiveUrlProtocol(String url) {
    try {
      final uri = Uri.parse(url);
      return sensitiveProtocols.contains(uri.scheme.toLowerCase());
    } catch (_) {
      return false;
    }
  }

  /// Whether a package name is considered sensitive.
  bool isSensitivePackage(String packageName) {
    for (final prefix in sensitivePackages) {
      if (packageName.startsWith(prefix)) {
        return true;
      }
    }
    return false;
  }

  /// Validates that a package name matches Android package naming rules.
  ///
  /// Must be lowercase alphanumeric + dots, at least 2 segments,
  /// each segment starting with a letter.
  bool isValidPackageName(String packageName) {
    final pattern = RegExp(
      r'^[a-z][a-z0-9]*(\.[a-z][a-z0-9]*)+$',
    );
    return pattern.hasMatch(packageName);
  }

  /// Validates that a settings key contains only safe characters.
  bool isValidSettingsKey(String key) {
    final pattern = RegExp(r'^[a-z][a-z0-9_]*$');
    return pattern.hasMatch(key);
  }

  /// Validates that a URL uses an allowed protocol.
  bool isAllowedUrlProtocol(String url) {
    try {
      final uri = Uri.parse(url);
      final allowed = {'http', 'https', 'tel', 'sms', 'mailto', 'market'};
      return allowed.contains(uri.scheme.toLowerCase());
    } catch (_) {
      return false;
    }
  }

  /// Enforces all security boundaries.
  ///
  /// Returns a list of violations found (empty if all boundaries are respected).
  List<SecurityBoundaryViolation> checkSecurityBoundaries({
    bool? attemptsShellExec,
    bool? attemptsArbitraryPackage,
    bool? attemptsIntentAbuse,
    bool? attemptsPermissionBypass,
    bool? attemptsAccessibilityAbuse,
    bool? attemptsHiddenBackgroundAction,
    bool? attemptsSecurityBypass,
    bool? attemptsSilentSensitiveAction,
  }) {
    final violations = <SecurityBoundaryViolation>[];

    if (attemptsShellExec == true) {
      violations.add(SecurityBoundaryViolation.shellExec);
    }
    if (attemptsArbitraryPackage == true) {
      violations.add(SecurityBoundaryViolation.arbitraryPackage);
    }
    if (attemptsIntentAbuse == true) {
      violations.add(SecurityBoundaryViolation.intentAbuse);
    }
    if (attemptsPermissionBypass == true) {
      violations.add(SecurityBoundaryViolation.permissionBypass);
    }
    if (attemptsAccessibilityAbuse == true) {
      violations.add(SecurityBoundaryViolation.accessibilityAbuse);
    }
    if (attemptsHiddenBackgroundAction == true) {
      violations.add(SecurityBoundaryViolation.hiddenBackgroundAction);
    }
    if (attemptsSecurityBypass == true) {
      violations.add(SecurityBoundaryViolation.securityBypass);
    }
    if (attemptsSilentSensitiveAction == true) {
      violations.add(SecurityBoundaryViolation.silentSensitiveAction);
    }

    return violations;
  }
}

/// Security boundary violations that must never be allowed.
enum SecurityBoundaryViolation {
  /// No shell/exec commands may be executed.
  shellExec,

  /// No arbitrary (unvalidated) package installation.
  arbitraryPackage,

  /// No intent abuse (sending broadcasts, starting components directly).
  intentAbuse,

  /// No permission bypass — all checks must run.
  permissionBypass,

  /// No accessibility service abuse.
  accessibilityAbuse,

  /// No hidden background actions without user awareness.
  hiddenBackgroundAction,

  /// No attempts to bypass security itself.
  securityBypass,

  /// No sensitive actions without explicit user confirmation.
  silentSensitiveAction;

  /// Bilingual message for this violation.
  String get message {
    switch (this) {
      case SecurityBoundaryViolation.shellExec:
        return 'Shell execution is not allowed / جێبەجێکردنی شێڵ ڕێگەپێدراو نییە';
      case SecurityBoundaryViolation.arbitraryPackage:
        return 'Arbitrary package installation is not allowed / '
            'دامەزراندنی پاکێجێکی نەناسراو ڕێگەپێدراو نییە';
      case SecurityBoundaryViolation.intentAbuse:
        return 'Intent abuse is not allowed / سوودوەرگرتن لە intent ڕێگەپێدراو نییە';
      case SecurityBoundaryViolation.permissionBypass:
        return 'Permission bypass is not allowed / تێپەڕاندنی ڕێگەپێدان ڕێگەپێدراو نییە';
      case SecurityBoundaryViolation.accessibilityAbuse:
        return 'Accessibility abuse is not allowed / '
            'سوودوەرگرتن لە دەستگەیشتن ڕێگەپێدراو نییە';
      case SecurityBoundaryViolation.hiddenBackgroundAction:
        return 'Hidden background actions are not allowed / '
            'کاری شاراوەی پشتەوە ڕێگەپێدراو نییە';
      case SecurityBoundaryViolation.securityBypass:
        return 'Security bypass is not allowed / تێپەڕاندنی ئاسایش ڕێگەپێدراو نییە';
      case SecurityBoundaryViolation.silentSensitiveAction:
        return 'Sensitive actions require confirmation / '
            'کاری هەستیار پێویستی بە ڕەزامەندییە';
    }
  }
}
