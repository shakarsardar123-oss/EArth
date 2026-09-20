import '../tool.dart';
import '../tool_definition.dart';
import '../tool_permission.dart';
import '../../agent/agent_confirmation_manager.dart';
import '../tool_arguments.dart';
import '../tool_result.dart';
import '../../device/device_channel.dart';
import '../../../core/errors/result.dart';

/// Regular expression for a valid Android package name.
///
/// Android package names follow the pattern:
/// - At least two segments separated by dots
/// - Each segment starts with a lowercase letter
/// - Segments contain only lowercase letters, digits, and underscores
/// - No segment starts with a digit or underscore
/// - No consecutive dots
/// - Maximum length of 255 characters
final RegExp _packageNamePattern = RegExp(
  r'^[a-z][a-z0-9]*(\.[a-z][a-z0-9]*)+$',
);

/// Maximum allowed length for a package name.
const int _maxPackageNameLength = 255;

/// Characters and patterns that must never appear in a package name
/// to prevent shell injection or command execution.
const List<String> _forbiddenPatterns = [
  ';',
  '&',
  '|',
  '`',
  '\$',
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

/// Tool to launch an Android application by its package name.
///
/// This is a **controlled** action — it opens an app via the
/// [DeviceChannel] abstraction using Android's Intent system.
///
/// **Security guarantees:**
/// - The [packageName] argument is strictly validated against the
///   Android package-name format (no shell metacharacters allowed).
/// - No `Runtime.exec`, `ProcessBuilder`, or shell commands are used.
/// - The native side uses `packageManager.getLaunchIntentForPackage()`
///   — if the package is not installed or has no launchable activity,
///   a structured failure is returned.
/// - Package name is passed through [ToolRegistry.sanitizeArguments]
///   at the registry level as an additional defence-in-depth layer.
///
/// **Risk level:** [ToolRiskLevel.low] — the tool has a visible side
/// effect (opening an app) but is not destructive or irreversible.
/// No user confirmation is required by default.
///
/// **Permission:** [ToolPermission.system] — launching apps is a
/// system-level capability.
class AppLaunchTool extends Tool {
  final DeviceChannel _deviceChannel;

  AppLaunchTool(this._deviceChannel);

  @override
  ToolDefinition get definition => const ToolDefinition(
        name: 'app_launch',
        description:
            'ئەپێک بکەرەوە بە ناوی پاکێجەکەی. '
            '— '
            'Launch an application by its Android package name '
            '(e.g. com.android.chrome, com.whatsapp).',
        category: 'device',
        parameters: [
          ToolArgumentDef(
            name: 'packageName',
            type: 'string',
            description:
                'ناوی پاکێجی ئەپەکە (بۆ نموونە com.android.chrome). '
                '— '
                'Android package name of the app to launch '
                '(e.g. com.android.chrome, com.whatsapp).',
            isRequired: true,
            example: 'com.android.chrome',
            label: 'پاکێج',
            hintText: 'com.example.app',
            keyboardType: 'text',
          ),
        ],
        permissionRequirements: [
          ToolPermissionRequirement(
            permission: ToolPermission.system,
            isRequired: true,
            rationale:
                'پێویستە ڕێگەی سیستەم بۆ کردنەوەی ئەپ. '
                '— '
                'System permission is required to launch applications.',
          ),
        ],
        isDangerous: false,
        requiresConfirmation: false,
        tags: [
          'device',
          'app',
          'launch',
          'open',
          'ئەپ',
          'کردنەوە',
          'بکەرەوە',
        ],
        icon: 'launch',
        timeout: Duration(seconds: 15),
        riskLevel: ToolRiskLevel.low,
      );

  @override
  String? validateArguments(ToolArguments arguments) {
    final packageName = arguments.getString('packageName');

    // 1. Must not be null or empty
    if (packageName == null || packageName.isEmpty) {
      return 'packageName is required and cannot be empty. '
          '— پاکێج ناو پێویستە و نابێت بەتاڵ بێت.';
    }

    // 2. Must not be just whitespace
    if (packageName.trim().isEmpty) {
      return 'packageName cannot be whitespace only. '
          '— پاکێج ناو نابێت تەنها بۆشایی سپێیس بێت.';
    }

    // 3. Must not exceed maximum length
    if (packageName.length > _maxPackageNameLength) {
      return 'packageName exceeds maximum length of '
          '$_maxPackageNameLength characters. '
          '— پاکێج ناو لە $_maxPackageNameLength پیت زیاترە.';
    }

    // 4. Must not contain forbidden patterns (shell injection prevention)
    for (final pattern in _forbiddenPatterns) {
      if (packageName.contains(pattern)) {
        return 'packageName contains forbidden character "$pattern". '
            '— پاکێج ناو پیتی نادروست "$pattern" لەخۆ دەگرێت.';
      }
    }

    // 5. Must match valid Android package name format
    if (!_packageNamePattern.hasMatch(packageName)) {
      return 'packageName must be a valid Android package name '
          '(e.g. com.android.chrome). '
          '— پاکێج ناو دەبێت فۆرماتی دروستی ئەندرۆید بێت.';
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

    final packageName = arguments.getString('packageName')!;

    try {
      final result = await _deviceChannel.launchApp(packageName);

      if (!result.isSuccess) {
        return ToolResult.failure(
          result.errorMessage ?? 'App launch failed',
          errorCode: result.errorCode,
        );
      }

      // Enrich success result with the package name for traceability
      final data = Map<String, dynamic>.from(result.data ?? {});
      data['packageName'] = packageName;

      return ToolResult.success(data);
    } catch (e) {
      return ToolResult.failure(
        'App launch error: $e',
        errorCode: 'internalError',
      );
    }
  }
}
