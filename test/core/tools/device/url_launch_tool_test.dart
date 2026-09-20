import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/core/device/device_channel.dart';
import 'package:aura_assistant/core/device/stub_device_channel.dart';
import 'package:aura_assistant/core/tools/device/url_launch_tool.dart';
import 'package:aura_assistant/core/tools/device/app_launch_tool.dart';
import 'package:aura_assistant/core/tools/device/system_settings_tool.dart';
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
/// for [launchUrl] and stubs all other methods.
class FakeUrlChannel implements DeviceChannel {
  final DeviceChannelResult _launchResult;

  FakeUrlChannel(this._launchResult);

  @override
  Future<DeviceChannelResult> launchUrl(String url) async => _launchResult;

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
  Future<DeviceChannelResult> openSystemSettings(String settingsAction) async =>
      const DeviceChannelResult.failure('not used', errorCode: 'unused');
}

/// A [DeviceChannel] that records the url passed to [launchUrl]
/// and returns a configurable result.
class RecordingUrlChannel implements DeviceChannel {
  String? lastUrl;
  final DeviceChannelResult _result;

  RecordingUrlChannel(this._result);

  @override
  Future<DeviceChannelResult> launchUrl(String url) async {
    lastUrl = url;
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
  Future<DeviceChannelResult> openSystemSettings(String settingsAction) async =>
      const DeviceChannelResult.failure('not used', errorCode: 'unused');
}

/// A [DeviceChannel] that throws on every call.
class ThrowingUrlChannel implements DeviceChannel {
  final Object exception;

  ThrowingUrlChannel(this.exception);

  @override
  Future<DeviceChannelResult> launchUrl(String url) async => throw exception;

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
  Future<DeviceChannelResult> openSystemSettings(String settingsAction) async =>
      throw exception;
}

void main() {
  // ── Metadata & Definition ──────────────────────────────────────────

  group('UrlLaunchTool definition', () {
    UrlLaunchTool newTool() => UrlLaunchTool(
          FakeUrlChannel(
            const DeviceChannelResult.success({'launched': true}),
          ),
        );

    test('name is url_launch', () {
      expect(newTool().name, 'url_launch');
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
      expect(newTool().description, contains('بەستەر'));
    });

    test('description includes English text after separator', () {
      expect(newTool().description, contains('—'));
      expect(newTool().description, contains('Open a URL'));
    });

    test('tags include Kurdish Sorani words', () {
      final tags = newTool().definition.tags;
      expect(tags, contains('بەستەر'));
      expect(tags, contains('وێبگەر'));
      expect(tags, contains('بکەرەوە'));
    });

    test('tags include English words', () {
      final tags = newTool().definition.tags;
      expect(tags, contains('url'));
      expect(tags, contains('browser'));
      expect(tags, contains('device'));
      expect(tags, contains('open'));
    });

    test('icon is open_in_browser', () {
      expect(newTool().definition.icon, 'open_in_browser');
    });

    test('has one required parameter: url', () {
      final params = newTool().definition.parameters;
      expect(params, hasLength(1));
      expect(params.first.name, 'url');
      expect(params.first.type, 'string');
      expect(params.first.isRequired, isTrue);
    });

    test('url parameter description is bilingual', () {
      final param = newTool().definition.parameters.first;
      expect(param.description, contains('بەستەر'));
      expect(param.description, contains('Full URL to open'));
    });

    test('url parameter has example', () {
      final param = newTool().definition.parameters.first;
      expect(param.example, 'https://example.com');
    });

    test('timeout is 15 seconds', () {
      expect(newTool().definition.timeout, const Duration(seconds: 15));
    });
  });

  // ── Argument Validation ───────────────────────────────────────────

  group('UrlLaunchTool validateArguments', () {
    UrlLaunchTool newTool() => UrlLaunchTool(
          FakeUrlChannel(
            const DeviceChannelResult.success({'launched': true}),
          ),
        );

    // ── Valid URLs ──

    test('accepts https://example.com', () {
      final result = newTool().validateArguments(
        const ToolArguments({'url': 'https://example.com'}),
      );
      expect(result, isNull);
    });

    test('accepts http://example.com', () {
      final result = newTool().validateArguments(
        const ToolArguments({'url': 'http://example.com'}),
      );
      expect(result, isNull);
    });

    test('accepts https URL with path', () {
      final result = newTool().validateArguments(
        const ToolArguments({'url': 'https://example.com/page'}),
      );
      expect(result, isNull);
    });

    test('accepts https URL with query and fragment', () {
      final result = newTool().validateArguments(
        const ToolArguments({'url': 'https://example.com/search?q=test#top'}),
      );
      expect(result, isNull);
    });

    test('accepts https URL with port', () {
      final result = newTool().validateArguments(
        const ToolArguments({'url': 'https://example.com:8080/path'}),
      );
      expect(result, isNull);
    });

    // ── Empty / null / whitespace ──

    test('rejects missing url argument', () {
      final result = newTool().validateArguments(
        const ToolArguments({}),
      );
      expect(result, isNotNull);
      expect(result, contains('required'));
    });

    test('rejects empty url', () {
      final result = newTool().validateArguments(
        const ToolArguments({'url': ''}),
      );
      expect(result, isNotNull);
      expect(result, contains('empty'));
    });

    test('rejects whitespace-only url', () {
      final result = newTool().validateArguments(
        const ToolArguments({'url': '   \t  '}),
      );
      expect(result, isNotNull);
      expect(result, contains('whitespace'));
    });

    // ── Too long ──

    test('rejects url exceeding 2048 characters', () {
      final longUrl = 'https://example.com/${'a' * 2100}';
      final result = newTool().validateArguments(
        ToolArguments({'url': longUrl}),
      );
      expect(result, isNotNull);
      expect(result, contains('maximum length'));
    });

    // ── Missing scheme ──

    test('rejects url without scheme', () {
      final result = newTool().validateArguments(
        const ToolArguments({'url': 'example.com'}),
      );
      expect(result, isNotNull);
      expect(result, contains('scheme'));
    });

    test('rejects url with only scheme and no host', () {
      final result = newTool().validateArguments(
        const ToolArguments({'url': 'https://'}),
      );
      expect(result, isNotNull);
      expect(result, contains('host'));
    });

    // ── Forbidden schemes ──

    test('rejects javascript: scheme', () {
      final result = newTool().validateArguments(
        const ToolArguments({'url': 'javascript:alert(1)'}),
      );
      expect(result, isNotNull);
      expect(result, contains('not allowed'));
    });

    test('rejects data: scheme', () {
      final result = newTool().validateArguments(
        const ToolArguments({'url': 'data:text/html,<h1>test</h1>'}),
      );
      expect(result, isNotNull);
      expect(result, contains('not allowed'));
    });

    test('rejects file: scheme', () {
      final result = newTool().validateArguments(
        const ToolArguments({'url': 'file:///etc/passwd'}),
      );
      expect(result, isNotNull);
      expect(result, contains('not allowed'));
    });

    test('rejects intent: scheme', () {
      final result = newTool().validateArguments(
        const ToolArguments({'url': 'intent://example.com'}),
      );
      expect(result, isNotNull);
      expect(result, contains('not allowed'));
    });

    test('rejects ftp: scheme', () {
      final result = newTool().validateArguments(
        const ToolArguments({'url': 'ftp://example.com/file'}),
      );
      expect(result, isNotNull);
      expect(result, contains('scheme must be http or https'));
    });

    test('rejects content: scheme', () {
      final result = newTool().validateArguments(
        const ToolArguments({'url': 'content://com.app/data'}),
      );
      expect(result, isNotNull);
      expect(result, contains('scheme must be http or https'));
    });

    test('rejects about: scheme', () {
      final result = newTool().validateArguments(
        const ToolArguments({'url': 'about:blank'}),
      );
      expect(result, isNotNull);
      expect(result, contains('not allowed'));
    });

    // ── Control characters ──

    test('rejects url with control character (null byte)', () {
      final result = newTool().validateArguments(
        ToolArguments({'url': 'https://example.com\x00test'}),
      );
      expect(result, isNotNull);
      expect(result, contains('control'));
    });

    test('rejects url with control character (tab)', () {
      final result = newTool().validateArguments(
        ToolArguments({'url': 'https://example.com\x09path'}),
      );
      expect(result, isNotNull);
      expect(result, contains('control'));
    });

    // ── Shell injection prevention ──

    test('rejects url with semicolon (shell injection)', () {
      final result = newTool().validateArguments(
        const ToolArguments({'url': 'https://example.com;rm -rf /'}),
      );
      expect(result, isNotNull);
      expect(result, contains('forbidden'));
    });

    test('rejects url with ampersand (shell injection)', () {
      final result = newTool().validateArguments(
        const ToolArguments({'url': 'https://example.com&&ls'}),
      );
      expect(result, isNotNull);
      expect(result, contains('forbidden'));
    });

    test('rejects url with pipe (shell injection)', () {
      final result = newTool().validateArguments(
        const ToolArguments({'url': 'https://example.com|cat'}),
      );
      expect(result, isNotNull);
      expect(result, contains('forbidden'));
    });

    test('rejects url with backtick (shell injection)', () {
      final result = newTool().validateArguments(
        const ToolArguments({'url': 'https://example.com`whoami`'}),
      );
      expect(result, isNotNull);
      expect(result, contains('forbidden'));
    });

    test('rejects url with dollar sign (shell injection)', () {
      final result = newTool().validateArguments(
        const ToolArguments({'url': 'https://example.com\$HOME'}),
      );
      expect(result, isNotNull);
      expect(result, contains('forbidden'));
    });

    test('rejects url with parentheses (shell injection)', () {
      final result = newTool().validateArguments(
        const ToolArguments({'url': 'https://example.com(subshell)'}),
      );
      expect(result, isNotNull);
      expect(result, contains('forbidden'));
    });

    test('rejects url with angle brackets (redirection)', () {
      final result = newTool().validateArguments(
        const ToolArguments({'url': 'https://example.com>file'}),
      );
      expect(result, isNotNull);
      expect(result, contains('forbidden'));
    });

    test('rejects url with double dots (path traversal)', () {
      final result = newTool().validateArguments(
        const ToolArguments({'url': 'https://example.com/../etc/passwd'}),
      );
      expect(result, isNotNull);
      expect(result, contains('forbidden'));
    });

    test('rejects url with newline (injection)', () {
      final result = newTool().validateArguments(
        ToolArguments({'url': 'https://example.com\nrm -rf /'}),
      );
      expect(result, isNotNull);
      expect(result, contains('forbidden'));
    });

    test('validation error messages include Kurdish text', () {
      final result = newTool().validateArguments(
        const ToolArguments({'url': ''}),
      );
      expect(result, isNotNull);
      expect(result, contains('بەستەر'));
    });
  });

  // ── Execute - Success ──────────────────────────────────────────────

  group('UrlLaunchTool execution - success', () {
    test('returns success with launched true for https URL', () async {
      final fakeChannel = FakeUrlChannel(
        const DeviceChannelResult.success({'launched': true}),
      );
      final tool = UrlLaunchTool(fakeChannel);

      final result = await tool.execute(
        const ToolArguments({'url': 'https://example.com'}),
      );

      expect(result.isSuccess, isTrue);
      final data = result.data as Map<String, dynamic>;
      expect(data['launched'], isTrue);
      expect(data['url'], 'https://example.com');
    });

    test('passes url to channel correctly', () async {
      final recordingChannel = RecordingUrlChannel(
        const DeviceChannelResult.success({'launched': true}),
      );
      final tool = UrlLaunchTool(recordingChannel);

      await tool.execute(
        const ToolArguments({'url': 'https://google.com'}),
      );

      expect(recordingChannel.lastUrl, 'https://google.com');
    });

    test('returns success for http URL', () async {
      final fakeChannel = FakeUrlChannel(
        const DeviceChannelResult.success({'launched': true}),
      );
      final tool = UrlLaunchTool(fakeChannel);

      final result = await tool.execute(
        const ToolArguments({'url': 'http://example.com'}),
      );

      expect(result.isSuccess, isTrue);
    });

    test('returns success for URL with path and query', () async {
      final fakeChannel = FakeUrlChannel(
        const DeviceChannelResult.success({'launched': true}),
      );
      final tool = UrlLaunchTool(fakeChannel);

      final result = await tool.execute(
        const ToolArguments({'url': 'https://example.com/search?q=test'}),
      );

      expect(result.isSuccess, isTrue);
      final data = result.data as Map<String, dynamic>;
      expect(data['url'], 'https://example.com/search?q=test');
    });
  });

  // ── Execute - Validation Failure ──────────────────────────────────

  group('UrlLaunchTool execution - validation failure', () {
    test('returns failure for empty url', () async {
      final fakeChannel = FakeUrlChannel(
        const DeviceChannelResult.success({'launched': true}),
      );
      final tool = UrlLaunchTool(fakeChannel);

      final result = await tool.execute(
        const ToolArguments({'url': ''}),
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'invalidArguments');
      expect(result.errorMessage, contains('empty'));
    });

    test('returns failure for javascript: scheme', () async {
      final fakeChannel = FakeUrlChannel(
        const DeviceChannelResult.success({'launched': true}),
      );
      final tool = UrlLaunchTool(fakeChannel);

      final result = await tool.execute(
        const ToolArguments({'url': 'javascript:alert(1)'}),
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'invalidArguments');
    });

    test('returns failure for data: scheme', () async {
      final fakeChannel = FakeUrlChannel(
        const DeviceChannelResult.success({'launched': true}),
      );
      final tool = UrlLaunchTool(fakeChannel);

      final result = await tool.execute(
        const ToolArguments({'url': 'data:text/html,<h1>test</h1>'}),
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'invalidArguments');
    });

    test('does not call channel when validation fails', () async {
      final recordingChannel = RecordingUrlChannel(
        const DeviceChannelResult.success({'launched': true}),
      );
      final tool = UrlLaunchTool(recordingChannel);

      await tool.execute(
        const ToolArguments({'url': ''}),
      );

      expect(recordingChannel.lastUrl, isNull);
    });
  });

  // ── Execute - Channel Failure ─────────────────────────────────────

  group('UrlLaunchTool execution - channel failure', () {
    test('returns failure when channel returns launchFailed', () async {
      final fakeChannel = FakeUrlChannel(
        const DeviceChannelResult.failure(
          'URL launch failed',
          errorCode: 'launchFailed',
        ),
      );
      final tool = UrlLaunchTool(fakeChannel);

      final result = await tool.execute(
        const ToolArguments({'url': 'https://example.com'}),
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'launchFailed');
    });

    test('catches unexpected exception and returns internalError', () async {
      final throwingChannel = ThrowingUrlChannel(
        StateError('channel crash'),
      );
      final tool = UrlLaunchTool(throwingChannel);

      final result = await tool.execute(
        const ToolArguments({'url': 'https://example.com'}),
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'internalError');
      expect(result.errorMessage, contains('URL launch error'));
    });

    test('handles null errorMessage from channel gracefully', () async {
      final fakeChannel = FakeUrlChannel(
        const DeviceChannelResult.failure(
          null,
          errorCode: 'unknown',
        ),
      );
      final tool = UrlLaunchTool(fakeChannel);

      final result = await tool.execute(
        const ToolArguments({'url': 'https://example.com'}),
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, 'URL launch failed');
    });
  });

  // ── StubDeviceChannel Integration ─────────────────────────────────

  group('UrlLaunchTool with StubDeviceChannel', () {
    test('returns platformUnsupported failure on stub channel', () async {
      final stubChannel = StubDeviceChannel(platformLabel: 'ios');
      final tool = UrlLaunchTool(stubChannel);

      final result = await tool.execute(
        const ToolArguments({'url': 'https://example.com'}),
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'platformUnsupported');
      expect(result.errorMessage, contains('not available'));
    });

    test('stub channel includes platform label in error message', () async {
      final stubChannel = StubDeviceChannel(platformLabel: 'web');
      final tool = UrlLaunchTool(stubChannel);


      final result = await tool.execute(
        const ToolArguments({'url': 'https://example.com'}),
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('web'));
    });
  });

  // ── ToolRegistry Integration ──────────────────────────────────────

  group('UrlLaunchTool in ToolRegistry', () {
    test('can be registered and retrieved by name', () {
      final registry = ToolRegistry();
      final fakeChannel = FakeUrlChannel(
        const DeviceChannelResult.success({'launched': true}),
      );
      final tool = UrlLaunchTool(fakeChannel);

      registry.register(tool);

      expect(registry.has('url_launch'), isTrue);
      expect(registry.get('url_launch'), same(tool));
    });

    test('is listed under device category', () {
      final registry = ToolRegistry();
      final fakeChannel = FakeUrlChannel(
        const DeviceChannelResult.success({'launched': true}),
      );
      final tool = UrlLaunchTool(fakeChannel);

      registry.register(tool);

      final deviceTools = registry.getByCategory('device');
      expect(deviceTools, hasLength(1));
      expect(deviceTools.first.name, 'url_launch');
    });

    test('is not in dangerous list', () {
      final registry = ToolRegistry();
      final fakeChannel = FakeUrlChannel(
        const DeviceChannelResult.success({'launched': true}),
      );
      final tool = UrlLaunchTool(fakeChannel);

      registry.register(tool);

      expect(registry.dangerous, isEmpty);
    });

    test('is not in requiringConfirmation list (low risk)', () {
      final registry = ToolRegistry();
      final fakeChannel = FakeUrlChannel(
        const DeviceChannelResult.success({'launched': true}),
      );
      final tool = UrlLaunchTool(fakeChannel);

      registry.register(tool);

      expect(registry.requiringConfirmation, isEmpty);
    });

    test('is allowed by default allowlist', () {
      final registry = ToolRegistry();
      final fakeChannel = FakeUrlChannel(
        const DeviceChannelResult.success({'launched': true}),
      );
      final tool = UrlLaunchTool(fakeChannel);

      registry.register(tool);

      expect(registry.isAllowed('url_launch'), isTrue);
    });

    test('OpenAI schema includes url_launch function with required param',
        () {
      final registry = ToolRegistry();
      final fakeChannel = FakeUrlChannel(
        const DeviceChannelResult.success({'launched': true}),
      );
      final tool = UrlLaunchTool(fakeChannel);

      registry.register(tool);

      final schemas = registry.openAISchemas;
      expect(schemas, hasLength(1));
      expect(schemas.first['type'], 'function');
      final fn = schemas.first['function'] as Map<String, dynamic>;
      expect(fn['name'], 'url_launch');
      expect(fn['description'], isNotNull);
      final params = fn['parameters'] as Map<String, dynamic>;
      expect(params['required'], contains('url'));
    });

    test('executes successfully through registry', () async {
      final registry = ToolRegistry();
      final fakeChannel = FakeUrlChannel(
        const DeviceChannelResult.success({'launched': true}),
      );
      final tool = UrlLaunchTool(fakeChannel);

      registry.register(tool);

      final retrieved = registry.getOrThrow('url_launch');
      final result = await retrieved.execute(
        const ToolArguments({'url': 'https://example.com'}),
      );

      expect(result.isSuccess, isTrue);
    });

    test('coexists with AppLaunchTool in registry', () {
      final registry = ToolRegistry();
      final fakeChannel = FakeUrlChannel(
        const DeviceChannelResult.success({'launched': true}),
      );

      registry.register(UrlLaunchTool(fakeChannel));
      registry.register(AppLaunchTool(fakeChannel));

      expect(registry.has('url_launch'), isTrue);
      expect(registry.has('app_launch'), isTrue);
      final deviceTools = registry.getByCategory('device');
      expect(deviceTools.length, 2);
    });

    test('coexists with SystemSettingsTool in registry', () {
      final registry = ToolRegistry();
      final fakeChannel = FakeUrlChannel(
        const DeviceChannelResult.success({'launched': true}),
      );

      registry.register(UrlLaunchTool(fakeChannel));
      registry.register(SystemSettingsTool(fakeChannel));

      expect(registry.has('url_launch'), isTrue);
      expect(registry.has('system_settings'), isTrue);
    });

    test('coexists with all existing device tools', () {
      final registry = ToolRegistry();
      final fakeChannel = FakeUrlChannel(
        const DeviceChannelResult.success({'launched': true}),
      );

      registry.register(UrlLaunchTool(fakeChannel));
      registry.register(AppLaunchTool(fakeChannel));
      registry.register(SystemSettingsTool(fakeChannel));
      registry.register(NetworkTool(fakeChannel));
      registry.register(BatteryTool(fakeChannel));
      registry.register(DeviceInfoTool(fakeChannel));

      expect(registry.has('url_launch'), isTrue);
      expect(registry.has('app_launch'), isTrue);
      expect(registry.has('system_settings'), isTrue);
      expect(registry.has('network'), isTrue);
      expect(registry.has('battery'), isTrue);
      expect(registry.has('device_info'), isTrue);
      final deviceTools = registry.getByCategory('device');
      expect(deviceTools.length, 6);
    });
  });

  // ── Permission & Risk Behavior ──────────────────────────────────────

  group('UrlLaunchTool permission and risk behavior', () {
    UrlLaunchTool newTool() => UrlLaunchTool(
          FakeUrlChannel(
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

  group('UrlLaunchTool structured results', () {
    test('success result includes url for traceability', () async {
      final fakeChannel = FakeUrlChannel(
        const DeviceChannelResult.success({'launched': true}),
      );
      final tool = UrlLaunchTool(fakeChannel);

      final result = await tool.execute(
        const ToolArguments({'url': 'https://example.com'}),
      );

      expect(result.isSuccess, isTrue);
      final data = result.data as Map<String, dynamic>;
      expect(data['url'], 'https://example.com');
      expect(data['launched'], isTrue);
    });

    test('failure result has errorCode', () async {
      final fakeChannel = FakeUrlChannel(
        const DeviceChannelResult.failure(
          'No browser available',
          errorCode: 'browserNotFound',
        ),
      );
      final tool = UrlLaunchTool(fakeChannel);

      final result = await tool.execute(
        const ToolArguments({'url': 'https://example.com'}),
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'browserNotFound');
      expect(result.errorMessage, isNotNull);
    });

    test('validation failure has invalidArguments errorCode', () async {
      final fakeChannel = FakeUrlChannel(
        const DeviceChannelResult.success({'launched': true}),
      );
      final tool = UrlLaunchTool(fakeChannel);

      final result = await tool.execute(
        const ToolArguments({'url': ''}),
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'invalidArguments');
    });

    test('internal error has internalError errorCode', () async {
      final throwingChannel = ThrowingUrlChannel(Exception('boom'));
      final tool = UrlLaunchTool(throwingChannel);

      final result = await tool.execute(
        const ToolArguments({'url': 'https://example.com'}),
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'internalError');
    });
  });

  // ── Security: Scheme Allowlist & Injection Prevention ────────────────

  group('UrlLaunchTool security - scheme allowlist and injection prevention',
      () {
    test('uses DeviceChannel.launchUrl, not shell execution', () async {
      final recordingChannel = RecordingUrlChannel(
        const DeviceChannelResult.success({'launched': true}),
      );
      final tool = UrlLaunchTool(recordingChannel);

      await tool.execute(
        const ToolArguments({'url': 'https://example.com'}),
      );

      // Verify the channel's launchUrl was called with correct url
      expect(recordingChannel.lastUrl, 'https://example.com');
    });

    test('validation prevents all forbidden schemes before channel call',
        () async {
      final recordingChannel = RecordingUrlChannel(
        const DeviceChannelResult.success({'launched': true}),
      );
      final tool = UrlLaunchTool(recordingChannel);

      final forbiddenUrls = [
        'javascript:alert(1)',
        'data:text/html,<script>alert(1)</script>',
        'file:///etc/passwd',
        'intent://example.com',
        'ftp://example.com/file',
        'content://com.app/data',
        'about:blank',
      ];

      for (final url in forbiddenUrls) {
        final result = await tool.execute(
          ToolArguments({'url': url}),
        );

        expect(result.isSuccess, isFalse,
            reason: 'Should reject scheme: $url');
        expect(result.errorCode, 'invalidArguments');
      }

      // Channel should never have been called for any of these
      expect(recordingChannel.lastUrl, isNull);
    });

    test('validation prevents all known injection patterns before channel call',
        () async {
      final recordingChannel = RecordingUrlChannel(
        const DeviceChannelResult.success({'launched': true}),
      );
      final tool = UrlLaunchTool(recordingChannel);

      final injectionPayloads = [
        'https://example.com;rm -rf /',
        'https://example.com&&ls',
        'https://example.com|cat /etc/passwd',
        'https://example.com`whoami`',
        'https://example.com\$HOME',
        'https://example.com(subshell)',
        'https://example.com>file',
        'https://example.com/../etc/passwd',
        'https://example.com\nrm -rf /',
      ];

      for (final payload in injectionPayloads) {
        final result = await tool.execute(
          ToolArguments({'url': payload}),
        );

        expect(result.isSuccess, isFalse,
            reason: 'Should reject injection: $payload');
        expect(result.errorCode, 'invalidArguments');
      }

      // Channel should never have been called for any of these
      expect(recordingChannel.lastUrl, isNull);
    });

    test('case-insensitive scheme check: JAVASCRIPT: is rejected', () {
      final fakeChannel = FakeUrlChannel(
        const DeviceChannelResult.success({'launched': true}),
      );
      final tool = UrlLaunchTool(fakeChannel);

      final result = tool.validateArguments(
        const ToolArguments({'url': 'JAVASCRIPT:alert(1)'}),
      );

      expect(result, isNotNull);
      expect(result, contains('not allowed'));
    });

    test('case-insensitive scheme check: Data: is rejected', () {
      final fakeChannel = FakeUrlChannel(
        const DeviceChannelResult.success({'launched': true}),
      );
      final tool = UrlLaunchTool(fakeChannel);

      final result = tool.validateArguments(
        const ToolArguments({'url': 'Data:text/html,test'}),
      );

      expect(result, isNotNull);
      expect(result, contains('not allowed'));
    });

    test('unknown scheme like mailto: is rejected (not in allowlist)', () {
      final fakeChannel = FakeUrlChannel(
        const DeviceChannelResult.success({'launched': true}),
      );
      final tool = UrlLaunchTool(fakeChannel);

      final result = tool.validateArguments(
        const ToolArguments({'url': 'mailto:user@example.com'}),
      );

      expect(result, isNotNull);
      expect(result, contains('scheme must be http or https'));
    });

    test('tel: scheme is rejected', () {
      final fakeChannel = FakeUrlChannel(
        const DeviceChannelResult.success({'launched': true}),
      );
      final tool = UrlLaunchTool(fakeChannel);

      final result = tool.validateArguments(
        const ToolArguments({'url': 'tel:+1234567890'}),
      );

      expect(result, isNotNull);
      expect(result, contains('scheme must be http or https'));
    });
  });
}
