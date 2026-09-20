/// Bilingual (Kurdish Sorani + English) security messages for AURA.
///
/// All security-related user-facing messages follow a consistent format:
/// Kurdish first (RTL), then English — ensuring accessibility for both.
library;

import 'permission_state.dart';
import '../agent/agent_confirmation_manager.dart';

/// Central repository for all security-related user-facing messages.
///
/// Messages are always bilingual: Kurdish Sorani (primary) + English.
/// This ensures RTL users see Kurdish first, while English speakers
/// can also understand the security context.
class SecurityMessages {
  const SecurityMessages();

  // ── Permission Messages ──

  /// Permission has been granted — proceed.
  String permissionGranted(String permissionName) =>
      'ڕێگەپێدان بۆ $permissionName دراوە / '
      'Permission for $permissionName granted';

  /// Permission has been denied — may request again.
  String permissionDenied(String permissionName) =>
      'ڕێگەپێدان بۆ $permissionName ڕەتکرایەوە / '
      'Permission for $permissionName denied';

  /// Permission has been permanently denied — must open settings.
  String permissionPermanentlyDenied(String permissionName) =>
      'ڕێگەپێدان بۆ $permissionName هەمیشە ڕەتکراوە / '
      'Permission for $permissionName permanently denied. '
      'تکایە لە ڕێکخستنەکاندا چالاک بکە / '
      'Please enable it in app settings';

  /// Permission is unsupported on this platform.
  String permissionUnsupported(String permissionName) =>
      'ڕێگەپێدان بۆ $permissionName لەم پلاتفۆرمەدا بەردەست نییە / '
      'Permission for $permissionName is not available on this platform';

  /// Permission check failed with an error.
  String permissionCheckError(String permissionName, String error) =>
      'کێشە لە پشکنینی ڕێگەپێدان بۆ $permissionName: $error / '
      'Error checking permission for $permissionName: $error';

  // ── Confirmation Messages ──

  /// Confirmation request for a tool action.
  String confirmationNeeded(String toolName, String actionDescription) =>
      'ئایا ڕێگە دەدەیت "$actionDescription" بکرێت؟\n'
      'ئامراز: $toolName / '
      'Do you allow "$actionDescription"?\n'
      'Tool: $toolName';

  /// Confirmation for sensitive settings access.
  String confirmationSensitiveSettings(String settingsKey) =>
      'ئایا ڕێگە دەدەیت ڕێکخستنی "$settingsKey" بکرێتەوە؟\n'
      'ئەمە ڕێکخستنێکی هەستیارە / '
      'Do you allow opening "$settingsKey" settings?\n'
      'This is a sensitive setting';

  /// Confirmation for sensitive URL launch.
  String confirmationSensitiveUrl(String url) =>
      'ئایا ڕێگە دەدەیت ئەم لینکە بکرێتەوە؟\n'
      '$url / '
      'Do you allow opening this link?\n'
      '$url';

  /// Confirmation for sensitive app launch.
  String confirmationSensitiveApp(String packageName) =>
      'ئایا ڕێگە dەدەیت ئەم ئەپە بکرێتەوە؟\n'
      '$packageName / '
      'Do you allow opening this app?\n'
      '$packageName';

  /// Confirmation for critical risk actions.
  String confirmationCriticalRisk(String actionDescription) =>
      '⚠️ ئەم کارە مەترسییەکی زۆرە!\n'
      'ئایا ڕێگە دەدەیت "$actionDescription" بکرێت؟ / '
      '⚠️ This action carries high risk!\n'
      'Do you allow "$actionDescription"?';

  /// Confirmation was accepted.
  String get confirmationAccepted =>
      'ڕەزامەندی دراوە / Confirmation accepted';

  /// Confirmation was denied.
  String get confirmationDenied =>
      'ڕەزامەندی ڕەتکرایەوە / Confirmation denied';

  /// Confirmation expired (timeout).
  String get confirmationExpired =>
      'کاتی ڕەزامەندی تەواو بوو / Confirmation expired';

  // ── Security Boundary Messages ──

  /// Shell execution blocked.
  String get shellExecBlocked =>
      'جێبەجێکردنی شێڵ ڕێگەپێدراو نییە / '
      'Shell execution is not allowed';

  /// Arbitrary package blocked.
  String get arbitraryPackageBlocked =>
      'دامەزراندنی پاکێجێکی نەناسراو ڕێگەپێدراو نییە / '
      'Arbitrary package installation is not allowed';

  /// Intent abuse blocked.
  String get intentAbuseBlocked =>
      'سوودوەرگرتن لە intent ڕێگەپێدراو نییە / '
      'Intent abuse is not allowed';

  /// Permission bypass blocked.
  String get permissionBypassBlocked =>
      'تێپەڕاندنی ڕێگەپێدان ڕێگەپێدراو نییە / '
      'Permission bypass is not allowed';

  /// Tool blocked due to security policy.
  String toolBlockedByPolicy(String toolName, String reason) =>
      'ئامرازی "$toolName" ڕاگیرا بەهۆی سیاسەتی ئاسایشەوە / '
      'Tool "$toolName" blocked by security policy: $reason';

  // ── Fallback Messages ──

  /// Graceful fallback on non-Android platform.
  String get platformFallback =>
      'ئەم تایبەتمەندییە لەسەر ئەم پلاتفۆرمەدا بەردەست نییە / '
      'This feature is not available on this platform';

  /// Action requires Android platform.
  String get requiresAndroid =>
      'ئەم کارە پێویستی بە ئەندرۆیدە / '
      'This action requires Android';

  // ── Risk Level Messages ──

  /// Human-readable description for a risk level.
  String riskLevelDescription(ToolRiskLevel level) {
    switch (level) {
      case ToolRiskLevel.none:
        return 'مەترسی نییە / No risk';
      case ToolRiskLevel.low:
        return 'مەترسی کەم / Low risk';
      case ToolRiskLevel.medium:
        return 'مەترسی مامناوەند / Medium risk';
      case ToolRiskLevel.high:
        return 'مەترسی زۆر / High risk';
      case ToolRiskLevel.critical:
        return 'مەترسی زۆر زۆر / Critical risk';
    }
  }

  // ── Permission Status Messages ──

  /// Human-readable message for a permission check result.
  String permissionStatusMessage(ToolPermissionStatus status) {
    switch (status) {
      case ToolPermissionStatus.granted:
        return 'ڕێگەپێدان دراوە / Permission granted';
      case ToolPermissionStatus.denied:
        return 'ڕێگەپێدان ڕەتکرایەوە / Permission denied';
      case ToolPermissionStatus.permanentlyDenied:
        return 'ڕێگەپێدان هەمیشە ڕەتکراوە / '
            'Permission permanently denied';
      case ToolPermissionStatus.unsupported:
        return 'ڕێگەپێدان بەردەست نییە / Permission unsupported';
    }
  }

  // ── Validation Messages ──

  /// Invalid package name format.
  String get invalidPackageName =>
      'ناوی پاکێج نادروستە / Invalid package name format';

  /// Invalid settings key format.
  String get invalidSettingsKey =>
      'کلیلی ڕێکخستن نادروستە / Invalid settings key format';

  /// Disallowed URL protocol.
  String get disallowedUrlProtocol =>
      'پرۆتۆکۆلی URL ڕێگەپێدراو نییە / URL protocol not allowed';
}
