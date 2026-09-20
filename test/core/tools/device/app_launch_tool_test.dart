import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/core/device/device_channel.dart';
import 'package:aura_assistant/core/device/stub_device_channel.dart';
import 'package:aura_assistant/core/tools/device/app_launch_tool.dart';
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
/// for [launchApp] and stubs all other methods.
class FakeLaunchChannel implements DeviceChannel {
  final DeviceChannelResult _launchResult;

  FakeLaunchChannel(this._launchResult);

  @override
  Future<DeviceChannelResult> launchApp(String packageId) async =>
      _launchResult;

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
  Future<DeviceChannelResult> openSystemSettings(
          String settingsAction) async =>
      const DeviceChannelResult.failure('not used', errorCode: 'unused');

  @override
  Future<DeviceChannelResult> launchUrl(String url) async =>
      const DeviceChannelResult.failure('not used', errorCode: 'unused');
}

/// A [DeviceChannel] that throws on every call.
class ThrowingLaunchChannel implements DeviceChannel {
  final Object exception;

  ThrowingLaunchChannel(this.exception);

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
  Future<DeviceChannelResult> openSystemSettings(
          String settingsAction) async =>
      throw exception;

  @override
  Future<DeviceChannelResult> launchUrl(String url) async =>
      throw exception;
}

/// A [DeviceChannel] that records the packageId passed to [launchApp]
/// and returns a configurable result.
class RecordingLaunchChannel implements DeviceChannel {
  String? lastPackageId;
  final DeviceChannelResult _result;

  RecordingLaunchChannel(this._result);

  @override
  Future<DeviceChannelResult> launchApp(String packageId) async {
    lastPackageId = packageId;
    return _result;
  }

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
  Future<DeviceChannelResult> openSystemSettings(
          String settingsAction) async =>
      const DeviceChannelResult.failure('not used', errorCode: 'unused');

  @override
  Future<DeviceChannelResult> launchUrl(String url) async =>
      const DeviceChannelResult.failure('not used', errorCode: 'unused');
}

void main() {
  // ── Metadata & Definition ──────────────────────────────────────────

  group('AppLaunchTool definition', () {
    AppLaunchTool newTool() => AppLaunchTool(
          FakeLaunchChannel(
            const DeviceChannelResult.success({'launched': true}),
          ),
        );

    test('name is app_launch', () {
      expect(newTool().name, 'app_launch');
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
      expect(newTool().description, contains('ئەپێک بکەرەوە'));
    });

    test('description includes English text after separator', () {
      expect(newTool().description, contains('—'));
      expect(newTool().description, contains('Launch an application'));
    });

    test('tags include Kurdish Sorani words', () {
      final tags = newTool().definition.tags;
      expect(tags, contains('ئەپ'));
      expect(tags, contains('کردنەوە'));
      expect(tags, contains('بکەرەوە'));
    });

    test('tags include English words', () {
      final tags = newTool().definition.tags;
      expect(tags, contains('app'));
      expect(tags, contains('launch'));
      expect(tags, contains('open'));
      expect(tags, contains('device'));
    });

    test('icon is launch', () {
      expect(newTool().definition.icon, 'launch');
    });

    test('has one required parameter: packageName', () {
      final params = newTool().definition.parameters;
      expect(params, hasLength(1));
      expect(params.first.name, 'packageName');
      expect(params.first.type, 'string');
      expect(params.first.isRequired, isTrue);
    });

    test('packageName parameter description is bilingual', () {
      final param = newTool().definition.parameters.first;
      expect(param.description, contains('پاکێج'));
      expect(param.description, contains('Android package name'));
    });

    test('packageName parameter has example', () {
      final param = newTool().definition.parameters.first;
      expect(param.example, 'com.android.chrome');
    });

    test('timeout is 15 seconds', () {
      expect(newTool().definition.timeout, const Duration(seconds: 15));
    });

    test('version is 1.0.0', () {
      expect(newTool().definition.version, '1.0.0');
    });
  });

  // ── Argument Validation ───────────────────────────────────────────

  group('AppLaunchTool validateArguments', () {
    AppLaunchTool newTool() => AppLaunchTool(
          FakeLaunchChannel(
            const DeviceChannelResult.success({'launched': true}),
          ),
        );

    // ── Valid package names ──

    test('accepts valid package name com.android.chrome', () {
      final result = newTool().validateArguments(
        const ToolArguments({'packageName': 'com.android.chrome'}),
      );
      expect(result, isNull);
    });

    test('accepts valid package name com.whatsapp', () {
      final result = newTool().validateArguments(
        const ToolArguments({'packageName': 'com.whatsapp'}),
      );
      expect(result, isNull);
    });

    test('accepts valid package name com.google.android.apps.maps', () {
      final result = newTool().validateArguments(
        const ToolArguments(
            {'packageName': 'com.google.android.apps.maps'}),
      );
      expect(result, isNull);
    });

    test('accepts package name with digits com.app2.app3', () {
      final result = newTool().validateArguments(
        const ToolArguments({'packageName': 'com.app2.app3'}),
      );
      expect(result, isNull);
    });

    // ── Empty / null / whitespace ──

    test('rejects missing packageName argument', () {
      final result = newTool().validateArguments(
        const ToolArguments({}),
      );
      expect(result, isNotNull);
      expect(result, contains('required'));
    });

    test('rejects empty packageName', () {
      final result = newTool().validateArguments(
        const ToolArguments({'packageName': ''}),
      );
      expect(result, isNotNull);
      expect(result, contains('empty'));
    });

    test('rejects whitespace-only packageName', () {
      final result = newTool().validateArguments(
        const ToolArguments({'packageName': '   \t  '}),
      );
      expect(result, isNotNull);
      expect(result, contains('whitespace'));
    });

    // ── Malformed package names ──

    test('rejects package name without dots (single segment)', () {
      final result = newTool().validateArguments(
        const ToolArguments({'packageName': 'chrome'}),
      );
      expect(result, isNotNull);
      expect(result, contains('valid Android package'));
    });

    test('rejects package name starting with digit', () {
      final result = newTool().validateArguments(
        const ToolArguments({'packageName': 'com.9app'}),
      );
      expect(result, isNotNull);
      expect(result, contains('valid Android package'));
    });

    test('rejects package name starting with underscore segment', () {
      final result = newTool().validateArguments(
        const ToolArguments({'packageName': 'com._app'}),
      );
      expect(result, isNotNull);
      expect(result, contains('valid Android package'));
    });

    test('rejects package name with uppercase letters', () {
      final result = newTool().validateArguments(
        const ToolArguments({'packageName': 'Com.Android.Chrome'}),
      );
      expect(result, isNotNull);
      expect(result, contains('valid Android package'));
    });

    test('rejects package name with hyphens', () {
      final result = newTool().validateArguments(
        const ToolArguments({'packageName': 'com.android-chrome'}),
      );
      expect(result, isNotNull);
      expect(result, contains('valid Android package'));
    });

    // ── Too long package name ──

    test('rejects package name exceeding 255 characters', () {
      // Build a 256-char package name: a.b.c... repeated
      final longName = 'a.${'b' * 254}';
      final result = newTool().validateArguments(
        ToolArguments({'packageName': longName}),
      );
      expect(result, isNotNull);
      expect(result, contains('maximum length'));
    });

    test('accepts package name at exactly 255 characters', () {
      // Build exactly 255-char valid package: a.bbbb... with enough segments
      final segment = 'a' * 126; // 126 chars
      final name = 'c.$segment.$segment'; // c + . + 126 + . + 126 = 255
      final result = newTool().validateArguments(
        ToolArguments({'packageName': name}),
      );
      expect(result, isNull);
    });

    // ── Shell injection prevention ──

    test('rejects package name with semicolon (shell injection)', () {
      final result = newTool().validateArguments(
        const ToolArguments({'packageName': 'com.app;rm -rf /'}),
      );
      expect(result, isNotNull);
      expect(result, contains('forbidden'));
    });

    test('rejects package name with ampersand (shell injection)', () {
      final result = newTool().validateArguments(
        const ToolArguments({'packageName': 'com.app&&ls'}),
      );
      expect(result, isNotNull);
      expect(result, contains('forbidden'));
    });

    test('rejects package name with pipe (shell injection)', () {
      final result = newTool().validateArguments(
        const ToolArguments({'packageName': 'com.app|cat'}),
      );
      expect(result, isNotNull);
      expect(result, contains('forbidden'));
    });

    test('rejects package name with backtick (shell injection)', () {
      final result = newTool().validateArguments(
        const ToolArguments({'packageName': 'com.app`ls`'}),
      );
      expect(result, isNotNull);
      expect(result, contains('forbidden'));
    });

    test('rejects package name with dollar sign (shell injection)', () {
      final result = newTool().validateArguments(
        const ToolArguments({'packageName': 'com.app\$HOME'}),
      );
      expect(result, isNotNull);
      expect(result, contains('forbidden'));
    });

    test('rejects package name with parentheses (shell injection)', () {
      final result = newTool().validateArguments(
        const ToolArguments({'packageName': 'com.app(subshell)'}),
      );
      expect(result, isNotNull);
      expect(result, contains('forbidden'));
    });

    test('rejects package name with double dots (path traversal)', () {
      final result = newTool().validateArguments(
        const ToolArguments({'packageName': 'com..app'}),
      );
      expect(result, isNotNull);
      expect(result, contains('forbidden'));
    });

    test('rejects package name with double slash (path traversal)', () {
      final result = newTool().validateArguments(
        const ToolArguments({'packageName': 'com//app'}),
      );
      expect(result, isNotNull);
      expect(result, contains('forbidden'));
    });

    test('rejects package name with space (argument splitting)', () {
      final result = newTool().validateArguments(
        const ToolArguments({'packageName': 'com. my app'}),
      );
      expect(result, isNotNull);
      expect(result, contains('forbidden'));
    });

    test('rejects package name with newline (injection)', () {
      final result = newTool().validateArguments(
        ToolArguments({'packageName': 'com.app\nrm -rf /'}),
      );
      expect(result, isNotNull);
      expect(result, contains('forbidden'));
    });

    test('rejects package name with angle brackets (redirection)', () {
      final result = newTool().validateArguments(
        const ToolArguments({'packageName': 'com.app>file'}),
      );
      expect(result, isNotNull);
      expect(result, contains('forbidden'));
    });

    test('validation error messages include Kurdish text', () {
      final result = newTool().validateArguments(
        const ToolArguments({'packageName': ''}),
      );
      expect(result, isNotNull);
      expect(result, contains('پاکێج ناو'));
    });
  });

  // ── Execute - Success ──────────────────────────────────────────────

  group('AppLaunchTool execution - success', () {
    test('returns success with launched true', () async {
      final fakeChannel = FakeLaunchChannel(
        const DeviceChannelResult.success({'launched': true}),
      );
      final tool = AppLaunchTool(fakeChannel);

      final result = await tool.execute(
        const ToolArguments({'packageName': 'com.android.chrome'}),
      );

      expect(result.isSuccess, isTrue);
      final data = result.data as Map<String, dynamic>;
      expect(data['launched'], isTrue);
      expect(data['packageName'], 'com.android.chrome');
    });

    test('passes packageId to channel correctly', () async {
      final recordingChannel = RecordingLaunchChannel(
        const DeviceChannelResult.success({'launched': true}),
      );
      final tool = AppLaunchTool(recordingChannel);

      await tool.execute(
        const ToolArguments({'packageName': 'com.whatsapp'}),
      );

      expect(recordingChannel.lastPackageId, 'com.whatsapp');
    });

    test('returns success for com.google.android.apps.maps', () async {
      final fakeChannel = FakeLaunchChannel(
        const DeviceChannelResult.success({'launched': true}),
      );
      final tool = AppLaunchTool(fakeChannel);

      final result = await tool.execute(
        const ToolArguments(
            {'packageName': 'com.google.android.apps.maps'}),
      );

      expect(result.isSuccess, isTrue);
    });
  });

  // ── Execute - Validation Failure ──────────────────────────────────

  group('AppLaunchTool execution - validation failure', () {
    test('returns failure for empty packageName', () async {
      final fakeChannel = FakeLaunchChannel(
        const DeviceChannelResult.success({'launched': true}),
      );
      final tool = AppLaunchTool(fakeChannel);

      final result = await tool.execute(
        const ToolArguments({'packageName': ''}),
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'invalidArguments');
      expect(result.errorMessage, contains('empty'));
    });

    test('returns failure for whitespace packageName', () async {
      final fakeChannel = FakeLaunchChannel(
        const DeviceChannelResult.success({'launched': true}),
      );
      final tool = AppLaunchTool(fakeChannel);

      final result = await tool.execute(
        const ToolArguments({'packageName': '   '}),
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'invalidArguments');
    });

    test('returns failure for malformed packageName', () async {
      final fakeChannel = FakeLaunchChannel(
        const DeviceChannelResult.success({'launched': true}),
      );
      final tool = AppLaunchTool(fakeChannel);

      final result = await tool.execute(
        const ToolArguments({'packageName': 'chrome'}),
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'invalidArguments');
    });

    test('returns failure for shell injection in packageName', () async {
      final fakeChannel = FakeLaunchChannel(
        const DeviceChannelResult.success({'launched': true}),
      );
      final tool = AppLaunchTool(fakeChannel);

      final result = await tool.execute(
        const ToolArguments({'packageName': 'com.app;rm -rf'}),
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'invalidArguments');
      expect(result.errorMessage, contains('forbidden'));
    });

    test('does not call channel when validation fails', () async {
      final recordingChannel = RecordingLaunchChannel(
        const DeviceChannelResult.success({'launched': true}),
      );
      final tool = AppLaunchTool(recordingChannel);

      await tool.execute(
        const ToolArguments({'packageName': ''}),
      );

      expect(recordingChannel.lastPackageId, isNull);
    });
  });

  // ── Execute - Channel Failure ─────────────────────────────────────

  group('AppLaunchTool execution - channel failure', () {
    test('returns failure when channel returns appNotFound', () async {
      final fakeChannel = FakeLaunchChannel(
        const DeviceChannelResult.failure(
          'Package not found: com.unknown.app',
          errorCode: 'appNotFound',
        ),
      );
      final tool = AppLaunchTool(fakeChannel);

      final result = await tool.execute(
        const ToolArguments({'packageName': 'com.unknown.app'}),
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'appNotFound');
      expect(result.errorMessage, contains('not found'));
    });

    test('returns failure when channel returns launchFailed', () async {
      final fakeChannel = FakeLaunchChannel(
        const DeviceChannelResult.failure(
          'App has no launchable activity',
          errorCode: 'launchFailed',
        ),
      );
      final tool = AppLaunchTool(fakeChannel);

      final result = await tool.execute(
        const ToolArguments({'packageName': 'com.android.settings'}),
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'launchFailed');
    });

    test('catches unexpected exception and returns internalError', () async {
      final throwingChannel = ThrowingLaunchChannel(
        StateError('channel crash'),
      );
      final tool = AppLaunchTool(throwingChannel);

      final result = await tool.execute(
        const ToolArguments({'packageName': 'com.app.test'}),
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'internalError');
      expect(result.errorMessage, contains('App launch error'));
    });

    test('handles null errorMessage from channel gracefully', () async {
      final fakeChannel = FakeLaunchChannel(
        const DeviceChannelResult.failure(
          null,
          errorCode: 'unknown',
        ),
      );
      final tool = AppLaunchTool(fakeChannel);

      final result = await tool.execute(
        const ToolArguments({'packageName': 'com.app.test'}),
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, 'App launch failed');
    });
  });

  // ── StubDeviceChannel Integration ─────────────────────────────────

  group('AppLaunchTool with StubDeviceChannel', () {
    test('returns platformUnsupported failure on stub channel', () async {
      final stubChannel = StubDeviceChannel(platformLabel: 'ios');
      final tool = AppLaunchTool(stubChannel);

      final result = await tool.execute(
        const ToolArguments({'packageName': 'com.android.chrome'}),
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'platformUnsupported');
      expect(result.errorMessage, contains('not available'));
    });

    test('stub channel includes platform label in error message', () async {
      final stubChannel = StubDeviceChannel(platformLabel: 'web');
      final tool = AppLaunchTool(stubChannel);

      final result = await tool.execute(
        const ToolArguments({'packageName': 'com.android.chrome'}),
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('web'));
    });
  });

  // ── ToolRegistry Integration ──────────────────────────────────────

  group('AppLaunchTool in ToolRegistry', () {
    test('can be registered and retrieved by name', () {
      final registry = ToolRegistry();
      final fakeChannel = FakeLaunchChannel(
        const DeviceChannelResult.success({'launched': true}),
      );
      final tool = AppLaunchTool(fakeChannel);

      registry.register(tool);

      expect(registry.has('app_launch'), isTrue);
      expect(registry.get('app_launch'), same(tool));
    });

    test('is listed under device category', () {
      final registry = ToolRegistry();
      final fakeChannel = FakeLaunchChannel(
        const DeviceChannelResult.success({'launched': true}),
      );
      final tool = AppLaunchTool(fakeChannel);

      registry.register(tool);

      final deviceTools = registry.getByCategory('device');
      expect(deviceTools, hasLength(1));
      expect(deviceTools.first.name, 'app_launch');
    });

    test('is not in dangerous list', () {
      final registry = ToolRegistry();
      final fakeChannel = FakeLaunchChannel(
        const DeviceChannelResult.success({'launched': true}),
      );
      final tool = AppLaunchTool(fakeChannel);

      registry.register(tool);

      expect(registry.dangerous, isEmpty);
    });

    test('is not in requiringConfirmation list (low risk)', () {
      final registry = ToolRegistry();
      final fakeChannel = FakeLaunchChannel(
        const DeviceChannelResult.success({'launched': true}),
      );
      final tool = AppLaunchTool(fakeChannel);

      registry.register(tool);

      expect(registry.requiringConfirmation, isEmpty);
    });

    test('is allowed by default allowlist', () {
      final registry = ToolRegistry();
      final fakeChannel = FakeLaunchChannel(
        const DeviceChannelResult.success({'launched': true}),
      );
      final tool = AppLaunchTool(fakeChannel);

      registry.register(tool);

      expect(registry.isAllowed('app_launch'), isTrue);
    });

    test('OpenAI schema includes app_launch function with required param',
        () {
      final registry = ToolRegistry();
      final fakeChannel = FakeLaunchChannel(
        const DeviceChannelResult.success({'launched': true}),
      );
      final tool = AppLaunchTool(fakeChannel);

      registry.register(tool);

      final schemas = registry.openAISchemas;
      expect(schemas, hasLength(1));
      expect(schemas.first['type'], 'function');
      final fn = schemas.first['function'] as Map<String, dynamic>;
      expect(fn['name'], 'app_launch');
      expect(fn['description'], isNotNull);
      final params = fn['parameters'] as Map<String, dynamic>;
      expect(params['required'], contains('packageName'));
    });

    test('executes successfully through registry', () async {
      final registry = ToolRegistry();
      final fakeChannel = FakeLaunchChannel(
        const DeviceChannelResult.success({'launched': true}),
      );
      final tool = AppLaunchTool(fakeChannel);

      registry.register(tool);

      final retrieved = registry.getOrThrow('app_launch');
      final result = await retrieved.execute(
        const ToolArguments({'packageName': 'com.android.chrome'}),
      );

      expect(result.isSuccess, isTrue);
    });

    test('coexists with NetworkTool in registry', () {
      final registry = ToolRegistry();
      final fakeChannel = FakeLaunchChannel(
        const DeviceChannelResult.success({'launched': true}),
      );

      registry.register(AppLaunchTool(fakeChannel));
      registry.register(NetworkTool(fakeChannel));

      expect(registry.has('app_launch'), isTrue);
      expect(registry.has('network'), isTrue);
      final deviceTools = registry.getByCategory('device');
      expect(deviceTools.length, 2);
    });

    test('coexists with BatteryTool in registry', () {
      final registry = ToolRegistry();
      final fakeChannel = FakeLaunchChannel(
        const DeviceChannelResult.success({'launched': true}),
      );

      registry.register(AppLaunchTool(fakeChannel));
      registry.register(BatteryTool(fakeChannel));

      expect(registry.has('app_launch'), isTrue);
      expect(registry.has('battery'), isTrue);
    });

    test('coexists with DeviceInfoTool in registry', () {
      final registry = ToolRegistry();
      final fakeChannel = FakeLaunchChannel(
        const DeviceChannelResult.success({'launched': true}),
      );

      registry.register(AppLaunchTool(fakeChannel));
      registry.register(DeviceInfoTool(fakeChannel));

      expect(registry.has('app_launch'), isTrue);
      expect(registry.has('device_info'), isTrue);
    });

    test('coexists with all three existing device tools', () {
      final registry = ToolRegistry();
      final fakeChannel = FakeLaunchChannel(
        const DeviceChannelResult.success({'launched': true}),
      );

      registry.register(AppLaunchTool(fakeChannel));
      registry.register(NetworkTool(fakeChannel));
      registry.register(BatteryTool(fakeChannel));
      registry.register(DeviceInfoTool(fakeChannel));

      expect(registry.has('app_launch'), isTrue);
      expect(registry.has('network'), isTrue);
      expect(registry.has('battery'), isTrue);
      expect(registry.has('device_info'), isTrue);
      final deviceTools = registry.getByCategory('device');
      expect(deviceTools.length, 4);
    });
  });

  // ── Permission & Risk Behavior ──────────────────────────────────────

  group('AppLaunchTool permission and risk behavior', () {
    AppLaunchTool newTool() => AppLaunchTool(
          FakeLaunchChannel(
            const DeviceChannelResult.success({'launched': true}),
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

  group('AppLaunchTool structured results', () {
    test('success result includes packageName for traceability', () async {
      final fakeChannel = FakeLaunchChannel(
        const DeviceChannelResult.success({'launched': true}),
      );
      final tool = AppLaunchTool(fakeChannel);

      final result = await tool.execute(
        const ToolArguments({'packageName': 'com.android.chrome'}),
      );

      expect(result.isSuccess, isTrue);
      final data = result.data as Map<String, dynamic>;
      expect(data['packageName'], 'com.android.chrome');
      expect(data['launched'], isTrue);
    });

    test('failure result has errorCode', () async {
      final fakeChannel = FakeLaunchChannel(
        const DeviceChannelResult.failure(
          'App not installed',
          errorCode: 'appNotFound',
        ),
      );
      final tool = AppLaunchTool(fakeChannel);

      final result = await tool.execute(
        const ToolArguments({'packageName': 'com.unknown.app'}),
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'appNotFound');
      expect(result.errorMessage, isNotNull);
    });

    test('validation failure has invalidArguments errorCode', () async {
      final fakeChannel = FakeLaunchChannel(
        const DeviceChannelResult.success({'launched': true}),
      );
      final tool = AppLaunchTool(fakeChannel);

      final result = await tool.execute(
        const ToolArguments({'packageName': ''}),
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'invalidArguments');
    });

    test('internal error has internalError errorCode', () async {
      final throwingChannel = ThrowingLaunchChannel(Exception('boom'));
      final tool = AppLaunchTool(throwingChannel);

      final result = await tool.execute(
        const ToolArguments({'packageName': 'com.app.test'}),
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'internalError');
    });
  });

  // ── Security: No Shell Commands ─────────────────────────────────────

  group('AppLaunchTool security - no shell commands', () {
    test('uses DeviceChannel.launchApp, not shell execution', () async {
      // The tool only calls _deviceChannel.launchApp(packageName)
      // which maps to MethodChannel Intent, not Runtime.exec/shell.
      // This test verifies the channel is called correctly.
      final recordingChannel = RecordingLaunchChannel(
        const DeviceChannelResult.success({'launched': true}),
      );
      final tool = AppLaunchTool(recordingChannel);

      await tool.execute(
        const ToolArguments({'packageName': 'com.android.chrome'}),
      );

      // Verify the channel's launchApp was called with correct packageId
      expect(recordingChannel.lastPackageId, 'com.android.chrome');
    });

    test('validation prevents all known injection patterns before channel call',
        () async {
      final recordingChannel = RecordingLaunchChannel(
        const DeviceChannelResult.success({'launched': true}),
      );
      final tool = AppLaunchTool(recordingChannel);

      final injectionPayloads = [
        'com.app;rm -rf /',
        'com.app&&ls',
        'com.app|cat /etc/passwd',
        'com.app`whoami`',
        'com.app\$HOME',
        'com.app(subshell)',
        'com.app>file',
        'com..app',
        'com//app',
      ];

      for (final payload in injectionPayloads) {
        final result = await tool.execute(
          ToolArguments({'packageName': payload}),
        );

        expect(result.isSuccess, isFalse,
            reason: 'Should reject injection: $payload');
        expect(result.errorCode, 'invalidArguments');
      }

      // Channel should never have been called for any of these
      expect(recordingChannel.lastPackageId, isNull);
    });
  });
}
