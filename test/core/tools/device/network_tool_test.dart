import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/core/device/device_channel.dart';
import 'package:aura_assistant/core/device/stub_device_channel.dart';
import 'package:aura_assistant/core/tools/device/network_tool.dart';
import 'package:aura_assistant/core/tools/device/battery_tool.dart';
import 'package:aura_assistant/core/tools/device/device_info_tool.dart';
import 'package:aura_assistant/core/tools/tool_arguments.dart';
import 'package:aura_assistant/core/tools/tool_result.dart';
import 'package:aura_assistant/core/tools/tool_registry.dart';
import 'package:aura_assistant/core/tools/tool_permission.dart';
import 'package:aura_assistant/core/agent/agent_confirmation_manager.dart';

/// A fake [DeviceChannel] that returns configurable network results.
class FakeNetworkChannel implements DeviceChannel {
  final DeviceChannelResult _networkResult;

  FakeNetworkChannel(this._networkResult);

  @override
  Future<DeviceChannelResult> getNetworkInfo() async => _networkResult;

  @override
  Future<DeviceChannelResult> getBatteryInfo() async =>
      const DeviceChannelResult.failure('not used', errorCode: 'unused');

  @override
  Future<DeviceChannelResult> getDeviceInfo() async =>
      const DeviceChannelResult.failure('not used', errorCode: 'unused');

  @override
  Future<DeviceChannelResult> launchApp(String packageId) async =>
      const DeviceChannelResult.failure('not used', errorCode: 'unused');

  @override
  Future<DeviceChannelResult> openSystemSettings(String settingsAction) async =>
      const DeviceChannelResult.failure('not used', errorCode: 'unused');

  @override
  Future<DeviceChannelResult> launchUrl(String url) async =>
      const DeviceChannelResult.failure('not used', errorCode: 'unused');
}

/// A [DeviceChannel] that throws on every call.
class ThrowingNetworkChannel implements DeviceChannel {
  final Object exception;

  ThrowingNetworkChannel(this.exception);

  @override
  Future<DeviceChannelResult> getNetworkInfo() async => throw exception;

  @override
  Future<DeviceChannelResult> getBatteryInfo() async => throw exception;

  @override
  Future<DeviceChannelResult> getDeviceInfo() async => throw exception;

  @override
  Future<DeviceChannelResult> launchApp(String packageId) async =>
      throw exception;

  @override
  Future<DeviceChannelResult> openSystemSettings(String settingsAction) async =>
      throw exception;

  @override
  Future<DeviceChannelResult> launchUrl(String url) async =>
      throw exception;
}

void main() {
  // ── Metadata & Definition ──────────────────────────────────────────

  group('NetworkTool definition', () {
    test('name is network', () {
      final fakeChannel = FakeNetworkChannel(
        const DeviceChannelResult.success({}),
      );
      final tool = NetworkTool(fakeChannel);

      expect(tool.name, 'network');
    });

    test('category is device', () {
      final fakeChannel = FakeNetworkChannel(
        const DeviceChannelResult.success({}),
      );
      final tool = NetworkTool(fakeChannel);

      expect(tool.definition.category, 'device');
    });

    test('risk level is none', () {
      final fakeChannel = FakeNetworkChannel(
        const DeviceChannelResult.success({}),
      );
      final tool = NetworkTool(fakeChannel);

      expect(tool.definition.riskLevel, ToolRiskLevel.none);
    });

    test('is not dangerous and does not require confirmation', () {
      final fakeChannel = FakeNetworkChannel(
        const DeviceChannelResult.success({}),
      );
      final tool = NetworkTool(fakeChannel);

      expect(tool.definition.isDangerous, isFalse);
      expect(tool.definition.requiresConfirmation, isFalse);
    });

    test('requires ToolPermission.network', () {
      final fakeChannel = FakeNetworkChannel(
        const DeviceChannelResult.success({}),
      );
      final tool = NetworkTool(fakeChannel);

      expect(tool.definition.permissionRequirements, hasLength(1));
      final req = tool.definition.permissionRequirements.first;
      expect(req.permission, ToolPermission.network);
      expect(req.isRequired, isTrue);
    });

    test('description includes Kurdish Sorani text', () {
      final fakeChannel = FakeNetworkChannel(
        const DeviceChannelResult.success({}),
      );
      final tool = NetworkTool(fakeChannel);

      expect(tool.description, contains('زانیاری تۆڕ'));
    });

    test('description includes English text after separator', () {
      final fakeChannel = FakeNetworkChannel(
        const DeviceChannelResult.success({}),
      );
      final tool = NetworkTool(fakeChannel);

      expect(tool.description, contains('—'));
      expect(tool.description, contains('Get network connectivity'));
    });

    test('tags include Kurdish Sorani words', () {
      final fakeChannel = FakeNetworkChannel(
        const DeviceChannelResult.success({}),
      );
      final tool = NetworkTool(fakeChannel);

      expect(tool.definition.tags, contains('تۆڕ'));
      expect(tool.definition.tags, contains('ئینتەرنێت'));
      expect(tool.definition.tags, contains('پەیوەندی'));
    });

    test('tags include English words', () {
      final fakeChannel = FakeNetworkChannel(
        const DeviceChannelResult.success({}),
      );
      final tool = NetworkTool(fakeChannel);

      expect(tool.definition.tags, contains('network'));
      expect(tool.definition.tags, contains('device'));
      expect(tool.definition.tags, contains('wifi'));
    });

    test('icon is wifi', () {
      final fakeChannel = FakeNetworkChannel(
        const DeviceChannelResult.success({}),
      );
      final tool = NetworkTool(fakeChannel);

      expect(tool.definition.icon, 'wifi');
    });
  });

  // ── Connected Wi-Fi ────────────────────────────────────────────────

  group('NetworkTool execution - Wi-Fi connected', () {
    test('returns success with Wi-Fi connection info', () async {
      final fakeChannel = FakeNetworkChannel(
        DeviceChannelResult.success({
          'isConnected': true,
          'type': 'wifi',
          'networkName': 'HomeNetwork',
        }),
      );
      final tool = NetworkTool(fakeChannel);

      final result = await tool.execute(const ToolArguments({}));

      expect(result.isSuccess, isTrue);
      final data = result.data as Map<String, dynamic>;
      expect(data['isConnected'], isTrue);
      expect(data['type'], 'wifi');
      expect(data['networkName'], 'HomeNetwork');
    });

    test('returns Wi-Fi info with null networkName', () async {
      final fakeChannel = FakeNetworkChannel(
        DeviceChannelResult.success({
          'isConnected': true,
          'type': 'wifi',
          'networkName': null,
        }),
      );
      final tool = NetworkTool(fakeChannel);

      final result = await tool.execute(const ToolArguments({}));

      expect(result.isSuccess, isTrue);
      final data = result.data as Map<String, dynamic>;
      expect(data['isConnected'], isTrue);
      expect(data['type'], 'wifi');
      expect(data['networkName'], isNull);
    });
  });

  // ── Connected Mobile Data ──────────────────────────────────────────

  group('NetworkTool execution - Mobile data connected', () {
    test('returns success with mobile data info', () async {
      final fakeChannel = FakeNetworkChannel(
        DeviceChannelResult.success({
          'isConnected': true,
          'type': 'mobile',
          'networkName': null,
        }),
      );
      final tool = NetworkTool(fakeChannel);

      final result = await tool.execute(const ToolArguments({}));

      expect(result.isSuccess, isTrue);
      final data = result.data as Map<String, dynamic>;
      expect(data['isConnected'], isTrue);
      expect(data['type'], 'mobile');
      expect(data['networkName'], isNull);
    });
  });

  // ── Disconnected / Offline ──────────────────────────────────────────

  group('NetworkTool execution - Disconnected / Offline', () {
    test('returns success with no connection', () async {
      final fakeChannel = FakeNetworkChannel(
        DeviceChannelResult.success({
          'isConnected': false,
          'type': 'none',
          'networkName': null,
        }),
      );
      final tool = NetworkTool(fakeChannel);

      final result = await tool.execute(const ToolArguments({}));

      expect(result.isSuccess, isTrue);
      final data = result.data as Map<String, dynamic>;
      expect(data['isConnected'], isFalse);
      expect(data['type'], 'none');
    });
  });

  // ── Unknown network type ────────────────────────────────────────────

  group('NetworkTool execution - Unknown network type', () {
    test('returns success with unknown type', () async {
      final fakeChannel = FakeNetworkChannel(
        DeviceChannelResult.success({
          'isConnected': true,
          'type': 'unknown',
          'networkName': null,
        }),
      );
      final tool = NetworkTool(fakeChannel);

      final result = await tool.execute(const ToolArguments({}));

      expect(result.isSuccess, isTrue);
      final data = result.data as Map<String, dynamic>;
      expect(data['isConnected'], isTrue);
      expect(data['type'], 'unknown');
    });
  });

  // ── DeviceChannel Failure ──────────────────────────────────────────

  group('NetworkTool execution - channel failure', () {
    test('returns failure when channel returns platformUnsupported',
        () async {
      final fakeChannel = FakeNetworkChannel(
        const DeviceChannelResult.failure(
          'Network info not available on ios',
          errorCode: 'platformUnsupported',
        ),
      );
      final tool = NetworkTool(fakeChannel);

      final result = await tool.execute(const ToolArguments({}));

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'platformUnsupported');
      expect(result.errorMessage, contains('Network info not available'));
    });

    test('returns failure when channel returns generic error', () async {
      final fakeChannel = FakeNetworkChannel(
        const DeviceChannelResult.failure(
          'Permission denied',
          errorCode: 'permissionDenied',
        ),
      );
      final tool = NetworkTool(fakeChannel);

      final result = await tool.execute(const ToolArguments({}));

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'permissionDenied');
      expect(result.errorMessage, contains('Permission denied'));
    });

    test('catches unexpected exception and returns internalError', () async {
      final throwingChannel = ThrowingNetworkChannel(
        StateError('network crash'),
      );
      final tool = NetworkTool(throwingChannel);

      final result = await tool.execute(const ToolArguments({}));

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'internalError');
      expect(result.errorMessage, contains('Network info error'));
    });

    test('handles null errorMessage from channel gracefully', () async {
      final fakeChannel = FakeNetworkChannel(
        const DeviceChannelResult.failure(
          null,
          errorCode: 'unknown',
        ),
      );
      final tool = NetworkTool(fakeChannel);

      final result = await tool.execute(const ToolArguments({}));

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, 'Network info request failed');
    });
  });

  // ── Malformed / Invalid Channel Result ─────────────────────────────

  group('NetworkTool execution - edge cases', () {
    test('returns success even with empty data map', () async {
      final fakeChannel = FakeNetworkChannel(
        const DeviceChannelResult.success({}),
      );
      final tool = NetworkTool(fakeChannel);

      final result = await tool.execute(const ToolArguments({}));

      // Tool delegates to channel; an empty map is still success.
      expect(result.isSuccess, isTrue);
      final data = result.data as Map<String, dynamic>;
      expect(data, isEmpty);
    });

    test('returns success with extra unexpected keys in data', () async {
      final fakeChannel = FakeNetworkChannel(
        DeviceChannelResult.success({
          'isConnected': true,
          'type': 'wifi',
          'networkName': 'TestNet',
          'signalStrength': -65, // extra key
          'linkSpeed': 72, // extra key
        }),
      );
      final tool = NetworkTool(fakeChannel);

      final result = await tool.execute(const ToolArguments({}));

      expect(result.isSuccess, isTrue);
      final data = result.data as Map<String, dynamic>;
      expect(data['isConnected'], isTrue);
      expect(data['type'], 'wifi');
      expect(data['signalStrength'], -65);
    });

    test('returns success with ethernet connection type', () async {
      final fakeChannel = FakeNetworkChannel(
        DeviceChannelResult.success({
          'isConnected': true,
          'type': 'ethernet',
          'networkName': null,
        }),
      );
      final tool = NetworkTool(fakeChannel);

      final result = await tool.execute(const ToolArguments({}));

      expect(result.isSuccess, isTrue);
      final data = result.data as Map<String, dynamic>;
      expect(data['type'], 'ethernet');
      expect(data['isConnected'], isTrue);
    });
  });

  // ── StubDeviceChannel Integration ─────────────────────────────────

  group('NetworkTool with StubDeviceChannel', () {
    test('returns platformUnsupported failure on stub channel', () async {
      final stubChannel = StubDeviceChannel(platformLabel: 'ios');
      final tool = NetworkTool(stubChannel);

      final result = await tool.execute(const ToolArguments({}));

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'platformUnsupported');
      expect(result.errorMessage, contains('not available'));
    });

    test('stub channel includes platform label in error message', () async {
      final stubChannel = StubDeviceChannel(platformLabel: 'web');
      final tool = NetworkTool(stubChannel);

      final result = await tool.execute(const ToolArguments({}));

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('web'));
    });
  });

  // ── Tool Arguments Validation ──────────────────────────────────────

  group('NetworkTool arguments validation', () {
    test('executes with empty arguments map', () async {
      final fakeChannel = FakeNetworkChannel(
        DeviceChannelResult.success({
          'isConnected': true,
          'type': 'wifi',
          'networkName': 'Home',
        }),
      );
      final tool = NetworkTool(fakeChannel);

      // NetworkTool takes no parameters, so empty args should work.
      final result = await tool.execute(const ToolArguments({}));

      expect(result.isSuccess, isTrue);
    });

    test('ignores extra arguments it does not need', () async {
      final fakeChannel = FakeNetworkChannel(
        DeviceChannelResult.success({
          'isConnected': false,
          'type': 'none',
          'networkName': null,
        }),
      );
      final tool = NetworkTool(fakeChannel);

      // Pass irrelevant args; tool should ignore them.
      final result = await tool.execute(
        const ToolArguments({'irrelevant': 'value'}),
      );

      expect(result.isSuccess, isTrue);
    });

    test('validateArguments returns null (no validation needed)', () {
      final fakeChannel = FakeNetworkChannel(
        const DeviceChannelResult.success({}),
      );
      final tool = NetworkTool(fakeChannel);

      expect(tool.validateArguments(const ToolArguments({})), isNull);
    });
  });

  // ── ToolRegistry Integration ──────────────────────────────────────

  group('NetworkTool in ToolRegistry', () {
    test('can be registered and retrieved by name', () {
      final registry = ToolRegistry();
      final fakeChannel = FakeNetworkChannel(
        const DeviceChannelResult.success({}),
      );
      final tool = NetworkTool(fakeChannel);

      registry.register(tool);

      expect(registry.has('network'), isTrue);
      expect(registry.get('network'), same(tool));
    });

    test('is listed under device category', () {
      final registry = ToolRegistry();
      final fakeChannel = FakeNetworkChannel(
        const DeviceChannelResult.success({}),
      );
      final tool = NetworkTool(fakeChannel);

      registry.register(tool);

      final deviceTools = registry.getByCategory('device');
      expect(deviceTools, hasLength(1));
      expect(deviceTools.first.name, 'network');
    });

    test('is not dangerous and does not require confirmation', () {
      final registry = ToolRegistry();
      final fakeChannel = FakeNetworkChannel(
        const DeviceChannelResult.success({}),
      );
      final tool = NetworkTool(fakeChannel);

      registry.register(tool);

      expect(registry.dangerous, isEmpty);
      expect(registry.requiringConfirmation, isEmpty);
    });

    test('is allowed by default allowlist', () {
      final registry = ToolRegistry();
      final fakeChannel = FakeNetworkChannel(
        const DeviceChannelResult.success({}),
      );
      final tool = NetworkTool(fakeChannel);

      registry.register(tool);

      expect(registry.isAllowed('network'), isTrue);
    });

    test('OpenAI schema includes network function', () {
      final registry = ToolRegistry();
      final fakeChannel = FakeNetworkChannel(
        const DeviceChannelResult.success({}),
      );
      final tool = NetworkTool(fakeChannel);

      registry.register(tool);

      final schemas = registry.openAISchemas;
      expect(schemas, hasLength(1));
      expect(schemas.first['type'], 'function');
      final fn = schemas.first['function'] as Map<String, dynamic>;
      expect(fn['name'], 'network');
      expect(fn['description'], isNotNull);
    });

    test('executes successfully through registry', () async {
      final registry = ToolRegistry();
      final fakeChannel = FakeNetworkChannel(
        DeviceChannelResult.success({
          'isConnected': true,
          'type': 'wifi',
          'networkName': 'OfficeNet',
        }),
      );
      final tool = NetworkTool(fakeChannel);

      registry.register(tool);

      final retrieved = registry.getOrThrow('network');
      final result = await retrieved.execute(const ToolArguments({}));

      expect(result.isSuccess, isTrue);
      final data = result.data as Map<String, dynamic>;
      expect(data['isConnected'], isTrue);
      expect(data['type'], 'wifi');
    });

    test('executes with stub channel through registry', () async {
      final registry = ToolRegistry();
      final stubChannel = StubDeviceChannel(platformLabel: 'desktop');
      final tool = NetworkTool(stubChannel);

      registry.register(tool);

      final retrieved = registry.getOrThrow('network');
      final result = await retrieved.execute(const ToolArguments({}));

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'platformUnsupported');
    });

    test('coexists with BatteryTool in registry', () async {
      final registry = ToolRegistry();
      final fakeChannel = FakeNetworkChannel(
        const DeviceChannelResult.success({}),
      );

      registry.register(NetworkTool(fakeChannel));
      registry.register(BatteryTool(fakeChannel));

      expect(registry.has('network'), isTrue);
      expect(registry.has('battery'), isTrue);
      final deviceTools = registry.getByCategory('device');
      expect(deviceTools.length, 2);
    });

    test('coexists with DeviceInfoTool in registry', () async {
      final registry = ToolRegistry();
      final fakeChannel = FakeNetworkChannel(
        const DeviceChannelResult.success({}),
      );

      registry.register(NetworkTool(fakeChannel));
      registry.register(DeviceInfoTool(fakeChannel));

      expect(registry.has('network'), isTrue);
      expect(registry.has('device_info'), isTrue);
      final deviceTools = registry.getByCategory('device');
      expect(deviceTools.length, 2);
    });

    test('coexists with BatteryTool and DeviceInfoTool together', () async {
      final registry = ToolRegistry();
      final fakeChannel = FakeNetworkChannel(
        const DeviceChannelResult.success({}),
      );

      registry.register(NetworkTool(fakeChannel));
      registry.register(BatteryTool(fakeChannel));
      registry.register(DeviceInfoTool(fakeChannel));

      expect(registry.has('network'), isTrue);
      expect(registry.has('battery'), isTrue);
      expect(registry.has('device_info'), isTrue);
      final deviceTools = registry.getByCategory('device');
      expect(deviceTools.length, 3);
    });
  });

  // ── Permission & Risk Behavior ──────────────────────────────────────

  group('NetworkTool permission and risk behavior', () {
    test('permission requirement is network and is required', () {
      final fakeChannel = FakeNetworkChannel(
        const DeviceChannelResult.success({}),
      );
      final tool = NetworkTool(fakeChannel);

      final permReqs = tool.definition.permissionRequirements;
      expect(permReqs, hasLength(1));
      expect(permReqs.first.permission, ToolPermission.network);
      expect(permReqs.first.isRequired, isTrue);
    });

    test('risk level is none — no confirmation needed', () {
      final fakeChannel = FakeNetworkChannel(
        const DeviceChannelResult.success({}),
      );
      final tool = NetworkTool(fakeChannel);

      expect(tool.definition.riskLevel, ToolRiskLevel.none);
      expect(tool.definition.needsConfirmation, isFalse);
    });

    test('tool is not in dangerous or requiringConfirmation lists', () {
      final registry = ToolRegistry();
      final fakeChannel = FakeNetworkChannel(
        const DeviceChannelResult.success({}),
      );
      final tool = NetworkTool(fakeChannel);

      registry.register(tool);

      expect(registry.dangerous, isEmpty);
      expect(registry.requiringConfirmation, isEmpty);
    });
  });
}
