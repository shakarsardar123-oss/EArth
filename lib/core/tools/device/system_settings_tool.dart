import '../tool.dart';
import '../tool_definition.dart';
import '../tool_permission.dart';
import '../../agent/agent_confirmation_manager.dart';
import '../tool_arguments.dart';
import '../tool_result.dart';
import '../../device/device_channel.dart';
import '../../../core/errors/result.dart';

/// Allowlist of safe system settings keys mapped to their
/// Android `Settings.ACTION_*` constant strings.
///
/// Only these keys are accepted by the tool. Any other key is
/// rejected to prevent arbitrary intent injection.
const Map<String, String> _settingsAllowlist = {
  'wifi': 'android.settings.WIFI_SETTINGS',
  'bluetooth': 'android.settings.BLUETOOTH_SETTINGS',
  'network': 'android.settings.WIRELESS_SETTINGS',
  'sound': 'android.settings.SOUND_SETTINGS',
  'display': 'android.settings.DISPLAY_SETTINGS',
  'battery': 'android.settings.BATTERY_SAVER_SETTINGS',
  'applications': 'android.settings.APPLICATION_SETTINGS',
  'location': 'android.settings.LOCATION_SOURCE_SETTINGS',
  'security': 'android.settings.SECURITY_SETTINGS',
  'accessibility': 'android.settings.ACCESSIBILITY_SETTINGS',
  'general': 'android.settings.SETTINGS',
};

/// Characters and patterns that must never appear in a settings key
/// to prevent shell injection or command execution.
const List<String> _forbiddenPatterns = [
  ';',
  '&',
  '|',
  '`',
  r'$',
  '(',
  ')',
  '{',
  '}',
  '<',
  '>',
  '!',
  '\n',
  '\r',
  '\t',
  ' ',
  '..',
  '//',
];

/// Tool to open Android system settings panels.
///
/// This is a **controlled** action — it opens a settings panel via the
/// [DeviceChannel] abstraction using Android's Intent system.
///
/// **Security guarantees:**
/// - The [setting] argument is validated against an explicit allowlist
///   of safe settings keys mapped to `Settings.ACTION_*` constants.
/// - No `Runtime.exec`, `ProcessBuilder`, or shell commands are used.
/// - The native side uses `startActivity(new Intent(action))` — if
///   the action string is not a valid Settings action, Android will
///   simply fail to open the panel.
/// - The setting key is passed through [ToolRegistry.sanitizeArguments]
///   at the registry level as an additional defence-in-depth layer.
///
/// **Risk level:** [ToolRiskLevel.low] — the tool has a visible side
/// effect (opening a settings panel) but is not destructive or
/// irreversible. No user confirmation is required by default.
///
/// **Permission:** [ToolPermission.system] — opening system settings
/// is a system-level capability.
class SystemSettingsTool extends Tool {
  final DeviceChannel _deviceChannel;

  SystemSettingsTool(this._deviceChannel);

  @override
  ToolDefinition get definition => const ToolDefinition(
        name: 'system_settings',
        description:
            'پانێلی ڕێکخستنەکانی سیستەم بکەرەوە (وایفای، بلوتوز، تەواوی شاشە، …). '
            '— '
            'Open an Android system settings panel '
            '(e.g. wifi, bluetooth, display, sound, battery).',
        category: 'device',
        parameters: [
          ToolArgumentDef(
            name: 'setting',
            type: 'string',
            description:
                'ناوی ڕێکخستنەکە: wifi, bluetooth, network, sound, display, '
                'battery, applications, location, security, accessibility, general. '
                '— '
                'Settings key to open: wifi, bluetooth, network, sound, display, '
                'battery, applications, location, security, accessibility, general.',
            isRequired: true,
            enumValues: [
              'wifi',
              'bluetooth',
              'network',
              'sound',
              'display',
              'battery',
              'applications',
              'location',
              'security',
              'accessibility',
              'general',
            ],
            example: 'wifi',
            label: 'ڕێکخستن',
            hintText: 'wifi',
            keyboardType: 'text',
          ),
        ],
        permissionRequirements: [
          ToolPermissionRequirement(
            permission: ToolPermission.system,
            isRequired: true,
            rationale:
                'پێویستە ڕێگەی سیستەم بۆ کردنەوەی ڕێکخستنەکان. '
                '— '
                'System permission is required to open system settings.',
          ),
        ],
        isDangerous: false,
        requiresConfirmation: false,
        tags: [
          'device',
          'settings',
          'open',
          'ڕێکخستن',
          'بکەرەوە',
          'سیستەم',
        ],
        icon: 'settings',
        timeout: Duration(seconds: 15),
        riskLevel: ToolRiskLevel.low,
      );

  @override
  String? validateArguments(ToolArguments arguments) {
    final setting = arguments.getString('setting');

    // 1. Must not be null or empty
    if (setting == null || setting.isEmpty) {
      return 'setting is required and cannot be empty. '
          '— ڕێکخستن پێویستە و نابێت بەتاڵ بێت.';
    }

    // 2. Must not be just whitespace
    if (setting.trim().isEmpty) {
      return 'setting cannot be whitespace only. '
          '— ڕێکخستن نابێت تەنها بۆشایی سپێیس بێت.';
    }

    // 3. Must not contain forbidden patterns (shell injection prevention)
    for (final pattern in _forbiddenPatterns) {
      if (setting.contains(pattern)) {
        return 'setting contains forbidden character "$pattern". '
            '— ڕێکخستن پیتی نادروست "$pattern" لەخۆ دەگرێت.';
      }
    }

    // 4. Must be in the allowlist
    if (!_settingsAllowlist.containsKey(setting)) {
      return 'setting must be one of: '
          '${_settingsAllowlist.keys.join(', ')}. '
          '— ڕێکخستن دەبێت یەکێک بێت لە: '
          '${_settingsAllowlist.keys.join(', ')}.';
    }

    return null; // Valid
  }

  @override
  Future<ToolResult> execute(ToolArguments arguments) async {
    // Validate arguments first
    final validationError = validateArguments(arguments);
    if (validationError != null) {
      return ToolResult.failure(
        validationError,
        errorCode: 'invalidArguments',
      );
    }

    final setting = arguments.getString('setting')!;
    final settingsAction = _settingsAllowlist[setting]!;

    try {
      final result =
          await _deviceChannel.openSystemSettings(settingsAction);

      if (!result.isSuccess) {
        return ToolResult.failure(
          result.errorMessage ?? 'System settings open failed',
          errorCode: result.errorCode,
        );
      }

      // Enrich success result with the setting key for traceability
      final data = Map<String, dynamic>.from(result.data ?? {});
      data['setting'] = setting;
      data['action'] = settingsAction;

      return ToolResult.success(data);
    } catch (e) {
      return ToolResult.failure(
        'System settings error: $e',
        errorCode: 'internalError',
      );
    }
  }
}
