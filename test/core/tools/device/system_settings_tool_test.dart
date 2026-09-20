import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/core/device/device_channel.dart';
import 'package:aura_assistant/core/device/stub_device_channel.dart';
import 'package:aura_assistant/core/tools/device/system_settings_tool.dart';
import 'package:aura_assistant/core/tools/device/app_launch_tool.dart';
import 'package:aura_assistant/core/tools/device/url_launch_tool.dart';
import 'package:aura_assistant/core/tools/device/network_tool.dart';
import 'package:aura_assistant/core/tools/device/battery_tool.dart';
import 'package:aura_assistant/core/tools/device/device_info_tool.dart';
import 'package:aura_assistant/core/tools/tool_arguments.dart';
import 'package:aura_assistant/core/tools/tool_result.dart';
import 'package:aura_assistant/core/tools/tool_registry.dart';
import 'package:aura_assistant/core/tools/tool_permission.dart';
import 'package:aura_assistant/core/agent/agent_confirmation_manager.dart';

// ── Fake Channels ──────────────────────────────────────────────────

/// A fake [DeviceChannel] that returns a configurable [DeviceChannelResult]
/// for [openSystemSettings] and stubs all other methods.
class FakeSettingsChannel implements DeviceChannel {
  final DeviceChannelResult _settingsResult;

  FakeSettingsChannel(this._settingsResult);

  @override
  Future<DeviceChannelResult> openSystemSettings(String settingsAction) async =>
      _settingsResult;

  @override
  Future<DeviceChannelResult> launchApp(String packageId) async =>
      const DeviceChannelResult.failure('not used', errorCode: 'unused');

  @override
  Future<DeviceChannelResult> getNetworkInfo() async =>
      const DeviceChannelResult.failure('not used', errorCode: 'unused');

  @override
  Future<DeviceChannelResult> getBatteryInfo() async =>
      const DeviceChannelResult.failure('not used', errorCode: 'unused');

  @override
  Future<DeviceChannelResult> getDeviceInfo() async =>
      const DeviceChannelResult.failure('not used', errorCode: 'unused');

  @override
  Future<DeviceChannelResult> launchUrl(String url) async =>
      const DeviceChannelResult.failure('not used', errorCode: 'unused');
}

/// A [DeviceChannel] that records the settingsAction passed to [openSystemSettings]
/// and returns a configurable result.
class RecordingSettingsChannel implements DeviceChannel {
  String? lastSettingsAction;
  final DeviceChannelResult _result;

  RecordingSettingsChannel(this._result);

  @override
  Future<DeviceChannelResult> openSystemSettings(String settingsAction) async {
    lastSettingsAction = settingsAction;
    return _result;
  }

  @override
  Future<DeviceChannelResult> launchApp(String packageId) async =>
      const DeviceChannelResult.failure('not used', errorCode: 'unused');

  @override
  Future<DeviceChannelResult> getNetworkInfo() async =>
      const DeviceChannelResult.failure('not used', errorCode: 'unused');

  @override
  Future<DeviceChannelResult> getBatteryInfo() async =>
      const DeviceChannelResult.failure('not used', errorCode: 'unused');

  @override
  Future<DeviceChannelResult> getDeviceInfo() async =>
      const DeviceChannelResult.failure('not used', errorCode: 'unused');

  @override
  Future<DeviceChannelResult> launchUrl(String url) async =>
      const DeviceChannelResult.failure('not used', errorCode: 'unused');
}

/// A [DeviceChannel] that throws on every call.
class ThrowingSettingsChannel implements DeviceChannel {
  final Object exception;

  ThrowingSettingsChannel(this.exception);

  @override
  Future<DeviceChannelResult> openSystemSettings(String settingsAction) async =>
      throw exception;

  @override
  Future<DeviceChannelResult> launchApp(String packageId) async =>
      throw exception;

  @override
  Future<DeviceChannelResult> getNetworkInfo() async => throw exception;

  @override
  Future<DeviceChannelResult> getBatteryInfo() async => throw exception;

  @override
  Future<DeviceChannelResult> getDeviceInfo() async => throw exception;

  @override
  Future<DeviceChannelResult> launchUrl(String url) async => throw exception;
}

void main() {
  // ── Metadata & Definition ──────────────────────────────────────────

  group('SystemSettingsTool definition', () {
    SystemSettingsTool newTool() => SystemSettingsTool(
          FakeSettingsChannel(
            const DeviceChannelResult.success({'opened': true}),
          ),
        );

    test('name is system_settings', () {
      expect(newTool().name, 'system_settings');
    });

    test('category is device', () {
      expect(newTool().definition.category, 'device');
    });

    test('risk level is low', () {
      expect(newTool().definition.riskLevel, ToolRiskLevel.low);
    });

    test('is not dangerous and does not require explicit confirmation', () {
      expect(newTool().definition.isDangerous, isFalse);
      expect(newTool().definition.requiresConfirmation, isFalse);
    });

    test('needsConfirmation is false because low risk does not require it',
        () {
      expect(newTool().definition.needsConfirmation, isFalse);
    });

    test('requires ToolPermission.system', () {
      final permReqs = newTool().definition.permissionRequirements;
      expect(permReqs, hasLength(1));
      expect(permReqs.first.permission, ToolPermission.system);
      expect(permReqs.first.isRequired, isTrue);
    });

    test('permission rationale includes Kurdish Sorani text', () {
      final rationale =
          newTool().definition.permissionRequirements.first.rationale;
      expect(rationale, isNotNull);
      expect(rationale, contains('ڕێگەی سیستەم'));
    });

    test('description includes Kurdish Sorani text', () {
      expect(newTool().description, contains('ڕێکخستن'));
    });

    test('description includes English text after separator', () {
      expect(newTool().description, contains('—'));
      expect(newTool().description, contains('Open an Android system'));
    });

    test('tags include Kurdish Sorani words', () {
      final tags = newTool().definition.tags;
      expect(tags, contains('ڕێکخستن'));
      expect(tags, contains('بکەرەوە'));
      expect(tags, contains('سیستەم'));
    });

    test('tags include English words', () {
      final tags = newTool().definition.tags;
      expect(tags, contains('settings'));
      expect(tags, contains('device'));
      expect(tags, contains('open'));
    });

    test('icon is settings', () {
      expect(newTool().definition.icon, 'settings');
    });

    test('has one required parameter: setting', () {
      final params = newTool().definition.parameters;
      expect(params, hasLength(1));
      expect(params.first.name, 'setting');
      expect(params.first.type, 'string');
      expect(params.first.isRequired, isTrue);
    });

    test('setting parameter description is bilingual', () {
      final param = newTool().definition.parameters.first;
      expect(param.description, contains('ڕێکخستن'));
      expect(param.description, contains('Settings key'));
    });

    test('setting parameter has examples', () {
      final param = newTool().definition.parameters.first;
      expect(param.example, isNotNull);
      expect(param.example, isNotEmpty);
    });

    test('timeout is 15 seconds', () {
      expect(newTool().definition.timeout, const Duration(seconds: 15));
    });
  });

  // ── Argument Validation ───────────────────────────────────────────

  group('SystemSettingsTool validateArguments', () {
    SystemSettingsTool newTool() => SystemSettingsTool(
          FakeSettingsChannel(
            const DeviceChannelResult.success({'opened': true}),
          ),
        );

    // ── Valid setting keys ──

    test('accepts wifi', () {
      final result = newTool().validateArguments(
        const ToolArguments({'setting': 'wifi'}),
      );
      expect(result, isNull);
    });

    test('accepts bluetooth', () {
      final result = newTool().validateArguments(
        const ToolArguments({'setting': 'bluetooth'}),
      );
      expect(result, isNull);
    });

    test('accepts network', () {
      final result = newTool().validateArguments(
        const ToolArguments({'setting': 'network'}),
      );
      expect(result, isNull);
    });

    test('accepts sound', () {
      final result = newTool().validateArguments(
        const ToolArguments({'setting': 'sound'}),
      );
      expect(result, isNull);
    });

    test('accepts display', () {
      final result = newTool().validateArguments(
        const ToolArguments({'setting': 'display'}),
      );
      expect(result, isNull);
    });

    test('accepts battery', () {
      final result = newTool().validateArguments(
        const ToolArguments({'setting': 'battery'}),
      );
      expect(result, isNull);
    });

    test('accepts applications', () {
      final result = newTool().validateArguments(
        const ToolArguments({'setting': 'applications'}),
      );
      expect(result, isNull);
    });

    test('accepts location', () {
      final result = newTool().validateArguments(
        const ToolArguments({'setting': 'location'}),
      );
      expect(result, isNull);
    });

    test('accepts security', () {
      final result = newTool().validateArguments(
        const ToolArguments({'setting': 'security'}),
      );
      expect(result, isNull);
    });

    test('accepts accessibility', () {
      final result = newTool().validateArguments(
        const ToolArguments({'setting': 'accessibility'}),
      );
      expect(result, isNull);
    });

    test('accepts general', () {
      final result = newTool().validateArguments(
        const ToolArguments({'setting': 'general'}),
      );
      expect(result, isNull);
    });

    // ── Empty / null / whitespace ──

    test('rejects missing setting argument', () {
      final result = newTool().validateArguments(
        const ToolArguments({}),
      );
      expect(result, isNotNull);
      expect(result, contains('required'));
    });

    test('rejects empty setting', () {
      final result = newTool().validateArguments(
        const ToolArguments({'setting': ''}),
      );
      expect(result, isNotNull);
      expect(result, contains('empty'));
    });

    test('rejects whitespace-only setting', () {
      final result = newTool().validateArguments(
        const ToolArguments({'setting': '   \t  '}),
      );
      expect(result, isNotNull);
      expect(result, contains('whitespace'));
    });

    // ── Not in allowlist ──

    test('rejects unknown setting key', () {
      final result = newTool().validateArguments(
        const ToolArguments({'setting': 'developer'}),
      );
      expect(result, isNotNull);
      expect(result, contains('یەکێک بێت لە'));
    });

    test('rejects setting with uppercase WiFi', () {
      final result = newTool().validateArguments(
        const ToolArguments({'setting': 'WiFi'}),
      );
      expect(result, isNotNull);
      expect(result, contains('یەکێک بێت لە'));
    });

    // ── Shell injection prevention ──

    test('rejects setting with semicolon (shell injection)', () {
      final result = newTool().validateArguments(
        const ToolArguments({'setting': 'wifi;rm -rf /'}),
      );
      expect(result, isNotNull);
      expect(result, contains('forbidden'));
    });

    test('rejects setting with ampersand (shell injection)', () {
      final result = newTool().validateArguments(
        const ToolArguments({'setting': 'wifi&&ls'}),
      );
      expect(result, isNotNull);
      expect(result, contains('forbidden'));
    });

    test('rejects setting with pipe (shell injection)', () {
      final result = newTool().validateArguments(
        const ToolArguments({'setting': 'wifi|cat'}),
      );
      expect(result, isNotNull);
      expect(result, contains('forbidden'));
    });

    test('rejects setting with backtick (shell injection)', () {
      final result = newTool().validateArguments(
        const ToolArguments({'setting': 'wifi`ls`'}),
      );
      expect(result, isNotNull);
      expect(result, contains('forbidden'));
    });

    test('rejects setting with dollar sign (shell injection)', () {
      final result = newTool().validateArguments(
        const ToolArguments({'setting': 'wifi\$HOME'}),
      );
      expect(result, isNotNull);
      expect(result, contains('forbidden'));
    });

    test('rejects setting with newline (injection)', () {
      final result = newTool().validateArguments(
        ToolArguments({'setting': 'wifi\nrm -rf /'}),
      );
      expect(result, isNotNull);
      expect(result, contains('forbidden'));
    });

    test('validation error messages include Kurdish text', () {
      final result = newTool().validateArguments(
        const ToolArguments({'setting': ''}),
      );
      expect(result, isNotNull);
      expect(result, contains('ڕێکخستن'));
    });
  });

  // ── Execute - Success ──────────────────────────────────────────────

  group('SystemSettingsTool execution - success', () {
    test('returns success with opened true for wifi', () async {
      final fakeChannel = FakeSettingsChannel(
        const DeviceChannelResult.success({'opened': true}),
      );
      final tool = SystemSettingsTool(fakeChannel);

      final result = await tool.execute(
        const ToolArguments({'setting': 'wifi'}),
      );

      expect(result.isSuccess, isTrue);
      final data = result.data as Map<String, dynamic>;
      expect(data['opened'], isTrue);
      expect(data['setting'], 'wifi');
    });

    test('passes correct ACTION string to channel for wifi', () async {
      final recordingChannel = RecordingSettingsChannel(
        const DeviceChannelResult.success({'opened': true}),
      );
      final tool = SystemSettingsTool(recordingChannel);

      await tool.execute(
        const ToolArguments({'setting': 'wifi'}),
      );

      expect(recordingChannel.lastSettingsAction,
          'android.settings.WIFI_SETTINGS');
    });

    test('passes correct ACTION string to channel for bluetooth', () async {
      final recordingChannel = RecordingSettingsChannel(
        const DeviceChannelResult.success({'opened': true}),
      );
      final tool = SystemSettingsTool(recordingChannel);

      await tool.execute(
        const ToolArguments({'setting': 'bluetooth'}),
      );

      expect(recordingChannel.lastSettingsAction,
          'android.settings.BLUETOOTH_SETTINGS');
    });

    test('passes correct ACTION string to channel for display', () async {
      final recordingChannel = RecordingSettingsChannel(
        const DeviceChannelResult.success({'opened': true}),
      );
      final tool = SystemSettingsTool(recordingChannel);

      await tool.execute(
        const ToolArguments({'setting': 'display'}),
      );

      expect(recordingChannel.lastSettingsAction,
          'android.settings.DISPLAY_SETTINGS');
    });

    test('returns success for security setting', () async {
      final fakeChannel = FakeSettingsChannel(
        const DeviceChannelResult.success({'opened': true}),
      );
      final tool = SystemSettingsTool(fakeChannel);

      final result = await tool.execute(
        const ToolArguments({'setting': 'security'}),
      );

      expect(result.isSuccess, isTrue);
      final data = result.data as Map<String, dynamic>;
      expect(data['setting'], 'security');
    });
  });

  // ── Execute - Validation Failure ──────────────────────────────────

  group('SystemSettingsTool execution - validation failure', () {
    test('returns failure for empty setting', () async {
      final fakeChannel = FakeSettingsChannel(
        const DeviceChannelResult.success({'opened': true}),
      );
      final tool = SystemSettingsTool(fakeChannel);

      final result = await tool.execute(
        const ToolArguments({'setting': ''}),
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'invalidArguments');
      expect(result.errorMessage, contains('empty'));
    });

    test('returns failure for unknown setting key', () async {
      final fakeChannel = FakeSettingsChannel(
        const DeviceChannelResult.success({'opened': true}),
      );
      final tool = SystemSettingsTool(fakeChannel);

      final result = await tool.execute(
        const ToolArguments({'setting': 'developer'}),
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'invalidArguments');
    });

    test('does not call channel when validation fails', () async {
      final recordingChannel = RecordingSettingsChannel(
        const DeviceChannelResult.success({'opened': true}),
      );
      final tool = SystemSettingsTool(recordingChannel);

      await tool.execute(
        const ToolArguments({'setting': ''}),
      );

      expect(recordingChannel.lastSettingsAction, isNull);
    });
  });

  // ── Execute - Channel Failure ─────────────────────────────────────

  group('SystemSettingsTool execution - channel failure', () {
    test('returns failure when channel returns launchFailed', () async {
      final fakeChannel = FakeSettingsChannel(
        const DeviceChannelResult.failure(
          'Settings not available',
          errorCode: 'launchFailed',
        ),
      );
      final tool = SystemSettingsTool(fakeChannel);

      final result = await tool.execute(
        const ToolArguments({'setting': 'wifi'}),
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'launchFailed');
    });

    test('catches unexpected exception and returns internalError', () async {
      final throwingChannel = ThrowingSettingsChannel(
        StateError('channel crash'),
      );
      final tool = SystemSettingsTool(throwingChannel);

      final result = await tool.execute(
        const ToolArguments({'setting': 'wifi'}),
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'internalError');
      expect(result.errorMessage, contains('System settings error'));
    });

    test('handles null errorMessage from channel gracefully', () async {
      final fakeChannel = FakeSettingsChannel(
        const DeviceChannelResult.failure(
          null,
          errorCode: 'unknown',
        ),
      );
      final tool = SystemSettingsTool(fakeChannel);

      final result = await tool.execute(
        const ToolArguments({'setting': 'wifi'}),
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, 'System settings open failed');
    });
  });

  // ── StubDeviceChannel Integration ─────────────────────────────────

  group('SystemSettingsTool with StubDeviceChannel', () {
    test('returns platformUnsupported failure on stub channel', () async {
      final stubChannel = StubDeviceChannel(platformLabel: 'ios');
      final tool = SystemSettingsTool(stubChannel);

      final result = await tool.execute(
        const ToolArguments({'setting': 'wifi'}),
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'platformUnsupported');
      expect(result.errorMessage, contains('not available'));
    });

    test('stub channel includes platform label in error message', () async {
      final stubChannel = StubDeviceChannel(platformLabel: 'web');
      final tool = SystemSettingsTool(stubChannel);

      final result = await tool.execute(
        const ToolArguments({'setting': 'bluetooth'}),
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('web'));
    });
  });

  // ── ToolRegistry Integration ──────────────────────────────────────

  group('SystemSettingsTool in ToolRegistry', () {
    test('can be registered and retrieved by name', () {
      final registry = ToolRegistry();
      final fakeChannel = FakeSettingsChannel(
        const DeviceChannelResult.success({'opened': true}),
      );
      final tool = SystemSettingsTool(fakeChannel);

      registry.register(tool);

      expect(registry.has('system_settings'), isTrue);
      expect(registry.get('system_settings'), same(tool));
    });

    test('is listed under device category', () {
      final registry = ToolRegistry();
      final fakeChannel = FakeSettingsChannel(
        const DeviceChannelResult.success({'opened': true}),
      );
      final tool = SystemSettingsTool(fakeChannel);

      registry.register(tool);

      final deviceTools = registry.getByCategory('device');
      expect(deviceTools, hasLength(1));
      expect(deviceTools.first.name, 'system_settings');
    });

    test('is not in dangerous list', () {
      final registry = ToolRegistry();
      final fakeChannel = FakeSettingsChannel(
        const DeviceChannelResult.success({'opened': true}),
      );
      final tool = SystemSettingsTool(fakeChannel);

      registry.register(tool);

      expect(registry.dangerous, isEmpty);
    });

    test('is not in requiringConfirmation list (low risk)', () {
      final registry = ToolRegistry();
      final fakeChannel = FakeSettingsChannel(
        const DeviceChannelResult.success({'opened': true}),
      );
      final tool = SystemSettingsTool(fakeChannel);

      registry.register(tool);

      expect(registry.requiringConfirmation, isEmpty);
    });

    test('is allowed by default allowlist', () {
      final registry = ToolRegistry();
      final fakeChannel = FakeSettingsChannel(
        const DeviceChannelResult.success({'opened': true}),
      );
      final tool = SystemSettingsTool(fakeChannel);

      registry.register(tool);

      expect(registry.isAllowed('system_settings'), isTrue);
    });

    test('OpenAI schema includes system_settings function with required param',
        () {
      final registry = ToolRegistry();
      final fakeChannel = FakeSettingsChannel(
        const DeviceChannelResult.success({'opened': true}),
      );
      final tool = SystemSettingsTool(fakeChannel);

      registry.register(tool);

      final schemas = registry.openAISchemas;
      expect(schemas, hasLength(1));
      expect(schemas.first['type'], 'function');
      final fn = schemas.first['function'] as Map<String, dynamic>;
      expect(fn['name'], 'system_settings');
      expect(fn['description'], isNotNull);
      final params = fn['parameters'] as Map<String, dynamic>;
      expect(params['required'], contains('setting'));
    });

    test('executes successfully through registry', () async {
      final registry = ToolRegistry();
      final fakeChannel = FakeSettingsChannel(
        const DeviceChannelResult.success({'opened': true}),
      );
      final tool = SystemSettingsTool(fakeChannel);

      registry.register(tool);

      final retrieved = registry.getOrThrow('system_settings');
      final result = await retrieved.execute(
        const ToolArguments({'setting': 'wifi'}),
      );

      expect(result.isSuccess, isTrue);
    });

    test('coexists with AppLaunchTool in registry', () {
      final registry = ToolRegistry();
      final fakeChannel = FakeSettingsChannel(
        const DeviceChannelResult.success({'opened': true}),
      );

      registry.register(SystemSettingsTool(fakeChannel));
      registry.register(AppLaunchTool(fakeChannel));

      expect(registry.has('system_settings'), isTrue);
      expect(registry.has('app_launch'), isTrue);
      final deviceTools = registry.getByCategory('device');
      expect(deviceTools.length, 2);
    });

    test('coexists with UrlLaunchTool in registry', () {
      final registry = ToolRegistry();
      final fakeChannel = FakeSettingsChannel(
        const DeviceChannelResult.success({'opened': true}),
      );

      registry.register(SystemSettingsTool(fakeChannel));
      registry.register(UrlLaunchTool(fakeChannel));

      expect(registry.has('system_settings'), isTrue);
      expect(registry.has('url_launch'), isTrue);
    });

    test('coexists with all existing device tools', () {
      final registry = ToolRegistry();
      final fakeChannel = FakeSettingsChannel(
        const DeviceChannelResult.success({'opened': true}),
      );

      registry.register(SystemSettingsTool(fakeChannel));
      registry.register(AppLaunchTool(fakeChannel));
      registry.register(NetworkTool(fakeChannel));
      registry.register(BatteryTool(fakeChannel));
      registry.register(DeviceInfoTool(fakeChannel));

      expect(registry.has('system_settings'), isTrue);
      expect(registry.has('app_launch'), isTrue);
      expect(registry.has('network'), isTrue);
      expect(registry.has('battery'), isTrue);
      expect(registry.has('device_info'), isTrue);
      final deviceTools = registry.getByCategory('device');
      expect(deviceTools.length, 5);
    });
  });

  // ── Permission & Risk Behavior ──────────────────────────────────────

  group('SystemSettingsTool permission and risk behavior', () {
    SystemSettingsTool newTool() => SystemSettingsTool(
          FakeSettingsChannel(
            const DeviceChannelResult.success({'opened': true}),
          ),
        );

    test('permission requirement is system and is required', () {
      final permReqs = newTool().definition.permissionRequirements;
      expect(permReqs, hasLength(1));
      expect(permReqs.first.permission, ToolPermission.system);
      expect(permReqs.first.isRequired, isTrue);
    });

    test('risk level is low — no confirmation needed', () {
      expect(newTool().definition.riskLevel, ToolRiskLevel.low);
      expect(newTool().definition.needsConfirmation, isFalse);
    });

    test('tool is not in dangerous or requiringConfirmation lists', () {
      final registry = ToolRegistry();
      final tool = newTool();

      registry.register(tool);

      expect(registry.dangerous, isEmpty);
      expect(registry.requiringConfirmation, isEmpty);
    });
  });

  // ── Structured Result Format ──────────────────────────────────────

  group('SystemSettingsTool structured results', () {
    test('success result includes setting key for traceability', () async {
      final fakeChannel = FakeSettingsChannel(
        const DeviceChannelResult.success({'opened': true}),
      );
      final tool = SystemSettingsTool(fakeChannel);

      final result = await tool.execute(
        const ToolArguments({'setting': 'bluetooth'}),
      );

      expect(result.isSuccess, isTrue);
      final data = result.data as Map<String, dynamic>;
      expect(data['setting'], 'bluetooth');
      expect(data['opened'], isTrue);
    });

    test('failure result has errorCode', () async {
      final fakeChannel = FakeSettingsChannel(
        const DeviceChannelResult.failure(
          'Settings panel not found',
          errorCode: 'settingsNotFound',
        ),
      );
      final tool = SystemSettingsTool(fakeChannel);

      final result = await tool.execute(
        const ToolArguments({'setting': 'wifi'}),
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'settingsNotFound');
      expect(result.errorMessage, isNotNull);
    });

    test('validation failure has invalidArguments errorCode', () async {
      final fakeChannel = FakeSettingsChannel(
        const DeviceChannelResult.success({'opened': true}),
      );
      final tool = SystemSettingsTool(fakeChannel);

      final result = await tool.execute(
        const ToolArguments({'setting': ''}),
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'invalidArguments');
    });

    test('internal error has internalError errorCode', () async {
      final throwingChannel = ThrowingSettingsChannel(Exception('boom'));
      final tool = SystemSettingsTool(throwingChannel);

      final result = await tool.execute(
        const ToolArguments({'setting': 'wifi'}),
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'internalError');
    });
  });

  // ── Security: No Shell Commands ─────────────────────────────────────

  group('SystemSettingsTool security - no shell commands', () {
    test('uses DeviceChannel.openSystemSettings, not shell execution',
        () async {
      final recordingChannel = RecordingSettingsChannel(
        const DeviceChannelResult.success({'opened': true}),
      );
      final tool = SystemSettingsTool(recordingChannel);

      await tool.execute(
        const ToolArguments({'setting': 'wifi'}),
      );

      // Verify the channel's openSystemSettings was called with correct action
      expect(recordingChannel.lastSettingsAction,
          'android.settings.WIFI_SETTINGS');
    });

    test('validation prevents all known injection patterns before channel call',
        () async {
      final recordingChannel = RecordingSettingsChannel(
        const DeviceChannelResult.success({'opened': true}),
      );
      final tool = SystemSettingsTool(recordingChannel);

      final injectionPayloads = [
        'wifi;rm -rf /',
        'wifi&&ls',
        'wifi|cat /etc/passwd',
        'wifi`whoami`',
        'wifi\$HOME',
        'wifi(subshell)',
        'wifi>file',
        'wifi..traversal',
      ];

      for (final payload in injectionPayloads) {
        final result = await tool.execute(
          ToolArguments({'setting': payload}),
        );

        expect(result.isSuccess, isFalse,
            reason: 'Should reject injection: $payload');
        expect(result.errorCode, 'invalidArguments');
      }

      // Channel should never have been called for any of these
      expect(recordingChannel.lastSettingsAction, isNull);
    });

    test('allowlist prevents opening arbitrary settings actions', () async {
      final recordingChannel = RecordingSettingsChannel(
        const DeviceChannelResult.success({'opened': true}),
      );
      final tool = SystemSettingsTool(recordingChannel);

      final invalidSettings = [
        'developer',
        'usb',
        'nfc',
        'cast',
        'privacy',
        'storage',
        'data_usage',
        'tethering',
        'vpn',
        'date_time',
      ];

      for (final invalid in invalidSettings) {
        final result = await tool.execute(
          ToolArguments({'setting': invalid}),
        );

        expect(result.isSuccess, isFalse,
            reason: 'Should reject setting: $invalid');
      }

      // Channel should never have been called
      expect(recordingChannel.lastSettingsAction, isNull);
    });
  });
}
