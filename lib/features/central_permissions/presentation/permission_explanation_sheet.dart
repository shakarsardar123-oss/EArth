// ───────────────────────────────────────────────────────────────────
// Step 16 – Central Permissions · Presentation · Explanation Sheet
// ───────────────────────────────────────────────────────────────────
// Bottom sheet explaining WHY a permission is needed before the
// system dialog appears.  Kurdish-first RTL, critical badges.
//
// Step 6 fix: Replaced .translate('key') calls (which don't exist
// on S) with a _resolveL10n helper that maps titleKey/bodyKey
// strings to the corresponding S getters.  Added missing import
// for DevicePermission from permission_status.dart.
// ───────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import 'package:aura_assistant/l10n/app_localizations.dart';
import 'package:aura_assistant/features/device_integration/domain/models/permission_status.dart';
import 'package:aura_assistant/features/central_permissions/domain/models/permission_explanation.dart';

/// Resolves a l10n key string to its localized value via [S].
///
/// Only the keys actually used by [PermissionExplanation.defaults]
/// are supported.  Falls back to the raw key if no getter matches.
String _resolveL10n(S s, String key) {
  switch (key) {
    // ── Permission titles ────────────────────────────────
    case 'perm_accessibility_title':
      return s.perm_accessibility_title;
    case 'perm_overlay_title':
      return s.perm_overlay_title;
    case 'perm_screen_capture_title':
      return s.perm_screen_capture_title;
    case 'perm_microphone_title':
      return s.perm_microphone_title;
    case 'perm_camera_title':
      return s.perm_camera_title;
    case 'perm_storage_title':
      return s.perm_storage_title;
    case 'perm_notification_title':
      return s.perm_notification_title;
    case 'perm_battery_title':
      return s.perm_battery_title;
    case 'perm_assistant_title':
      return s.perm_assistant_title;
    case 'perm_location_title':
      return s.perm_location_title;
    case 'perm_exact_alarm_title':
      return s.perm_exact_alarm_title;
    // ── Permission bodies ─────────────────────────────────
    case 'perm_accessibility_body':
      return s.perm_accessibility_body;
    case 'perm_overlay_body':
      return s.perm_overlay_body;
    case 'perm_screen_capture_body':
      return s.perm_screen_capture_body;
    case 'perm_microphone_body':
      return s.perm_microphone_body;
    case 'perm_camera_body':
      return s.perm_camera_body;
    case 'perm_storage_body':
      return s.perm_storage_body;
    case 'perm_notification_body':
      return s.perm_notification_body;
    case 'perm_battery_body':
      return s.perm_battery_body;
    case 'perm_assistant_body':
      return s.perm_assistant_body;
    case 'perm_location_body':
      return s.perm_location_body;
    case 'perm_exact_alarm_body':
      return s.perm_exact_alarm_body;
    // ── Shared keys ──────────────────────────────────────
    case 'perm_critical':
      return s.perm_critical;
    case 'perm_used_by':
      return s.perm_used_by;
    case 'perm_not_now':
      return s.perm_not_now;
    case 'perm_continue':
      return s.perm_continue;
    // ── Feature names (approximate – not full l10n keys) ──
    case 'feature_device_integration':
    case 'feature_floating_overlay':
    case 'feature_screen_capture':
    case 'feature_voice_screen':
    case 'feature_vision':
    case 'feature_file_storage':
    case 'feature_notifications':
    case 'feature_foreground_service':
    case 'feature_assistant_integration':
    case 'feature_location_services':
    case 'feature_exact_alarm':
    case 'feature_unknown':
      // Feature names are informational – fall back to key.
      return key.replaceFirst('feature_', '');
    default:
      // Unknown key – return as-is so the UI still renders.
      return key;
  }
}

/// Modal bottom sheet that explains why a permission is needed.
///
/// Returns `true` if the user taps "Continue", `false` if dismissed.
Future<bool> showPermissionExplanationSheet({
  required BuildContext context,
  required PermissionExplanation explanation,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _ExplanationSheet(explanation: explanation),
  ).then((v) => v ?? false);
}

class _ExplanationSheet extends StatelessWidget {
  final PermissionExplanation explanation;

  const _ExplanationSheet({required this.explanation});

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final theme = Theme.of(context);
    final s = S.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        children: [
          // ── Handle bar ────────────────────────────────────────────
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Title row ─────────────────────────────────────────────
          Row(
            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
            children: [
              _PermIcon(permission: explanation.permission),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _resolveL10n(s, explanation.titleKey),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (explanation.isCritical)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    s.perm_critical,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onError,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Body ──────────────────────────────────────────────────
          Text(
            _resolveL10n(s, explanation.bodyKey),
            style: theme.textTheme.bodyMedium,
            textAlign: isRtl ? TextAlign.right : TextAlign.left,
          ),

          const SizedBox(height: 12),

          // ── Feature hint ─────────────────────────────────────────
          Text(
            '${s.perm_used_by} ${_resolveL10n(s, 'feature_${explanation.featureName}')}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.hintColor,
            ),
            textAlign: isRtl ? TextAlign.right : TextAlign.left,
          ),

          const SizedBox(height: 24),

          // ── Actions ───────────────────────────────────────────────
          Row(
            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(s.perm_not_now),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(s.perm_continue),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Small icon representing a permission category.
class _PermIcon extends StatelessWidget {
  final DevicePermission permission;

  const _PermIcon({required this.permission});

  @override
  Widget build(BuildContext context) {
    final IconData icon = switch (permission) {
      DevicePermission.accessibility => Icons.accessibility_new,
      DevicePermission.overlay => Icons.layers,
      DevicePermission.screenCapture => Icons.screenshot_monitor,
      DevicePermission.microphone => Icons.mic,
      DevicePermission.camera => Icons.camera_alt,
      DevicePermission.storage => Icons.folder,
      DevicePermission.notification => Icons.notifications,
      DevicePermission.batteryOptimization => Icons.battery_charging_full,
      DevicePermission.assistant => Icons.assistant,
      DevicePermission.location => Icons.location_on,
      DevicePermission.exactAlarm => Icons.alarm,
    };

    return CircleAvatar(
      radius: 20,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Icon(icon, size: 20),
    );
  }
}
