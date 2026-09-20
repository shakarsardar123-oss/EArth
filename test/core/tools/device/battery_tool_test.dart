import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/core/device/device_channel.dart';
import 'package:aura_assistant/core/device/stub_device_channel.dart';
import 'package:aura_assistant/core/tools/device/battery_tool.dart';
import 'package:aura_assistant/core/tools/device/device_info_tool.dart';
import 'package:aura_assistant/core/tools/tool_arguments.dart';
import 'package:aura_assistant/core/tools/tool_result.dart';
import 'package:aura_assistant/core/tools/tool_registry.dart';
import 'package:aura_assistant/core/tools/tool_permission.dart';
import 'package:aura_assistant/core/agent/agent_confirmation_manager.dart';

/// A fake [DeviceChannel] that returns configurable battery results.
class FakeBatteryChannel implements DeviceChannel {
  final DeviceChannelResult _batteryResult;

  FakeBatteryChannel(this._batteryResult);

  @override
  Future<DeviceChannelResult> getBatteryInfo() async => _batteryResult;

  @override
  Future<DeviceChannelResult> getDeviceInfo() async =>
      const DeviceChannelResult.failure('not used', errorCode: 'unused');

  @override
  Future<DeviceChannelResult> getNetworkInfo() async =>
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
class ThrowingBatteryChannel implements DeviceChannel {
  final Object exception;

  ThrowingBatteryChannel(this.exception);

  @override
  Future<DeviceChannelResult> getBatteryInfo() async => throw exception;

  @override
  Future<DeviceChannelResult> getDeviceInfo() async => throw exception;

  @override
  Future<DeviceChannelResult> getNetworkInfo() async => throw exception;

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

  group('BatteryTool definition', () {
    test('name is battery', () {
      final fakeChannel = FakeBatteryChannel(
        const DeviceChannelResult.success({}),
      );
      final tool = BatteryTool(fakeChannel);

      expect(tool.name, 'battery');
    });

    test('category is device', () {
      final fakeChannel = FakeBatteryChannel(
        const DeviceChannelResult.success({}),
      );
      final tool = BatteryTool(fakeChannel);

      expect(tool.definition.category, 'device');
    });

    test('risk level is none', () {
      final fakeChannel = FakeBatteryChannel(
        const DeviceChannelResult.success({}),
      );
      final tool = BatteryTool(fakeChannel);

      expect(tool.definition.riskLevel, ToolRiskLevel.none);
    });

    test('is not dangerous and does not require confirmation', () {
      final fakeChannel = FakeBatteryChannel(
        const DeviceChannelResult.success({}),
      );
      final tool = BatteryTool(fakeChannel);

      expect(tool.definition.isDangerous, isFalse);
      expect(tool.definition.requiresConfirmation, isFalse);
    });

    test('requires ToolPermission.battery', () {
      final fakeChannel = FakeBatteryChannel(
        const DeviceChannelResult.success({}),
      );
      final tool = BatteryTool(fakeChannel);

      expect(tool.definition.permissionRequirements, hasLength(1));
      final req = tool.definition.permissionRequirements.first;
      expect(req.permission, ToolPermission.battery);
      expect(req.isRequired, isTrue);
    });

    test('description includes Kurdish Sorani text', () {
      final fakeChannel = FakeBatteryChannel(
        const DeviceChannelResult.success({}),
      );
      final tool = BatteryTool(fakeChannel);

      expect(tool.description, contains('زانیاری باتری'));
    });

    test('description includes English text after separator', () {
      final fakeChannel = FakeBatteryChannel(
        const DeviceChannelResult.success({}),
      );
      final tool = BatteryTool(fakeChannel);

      expect(tool.description, contains('—'));
      expect(tool.description, contains('Get battery information'));
    });

    test('tags include Kurdish Sorani words', () {
      final fakeChannel = FakeBatteryChannel(
        const DeviceChannelResult.success({}),
      );
      final tool = BatteryTool(fakeChannel);

      expect(tool.definition.tags, contains('باتری'));
      expect(tool.definition.tags, contains('بارکردن'));
    });

    test('tags include English words', () {
      final fakeChannel = FakeBatteryChannel(
        const DeviceChannelResult.success({}),
      );
      final tool = BatteryTool(fakeChannel);

      expect(tool.definition.tags, contains('battery'));
      expect(tool.definition.tags, contains('device'));
    });
  });

  // ── Battery Level Success ──────────────────────────────────────────

  group('BatteryTool execution - success', () {
    test('returns success with battery level', () async {
      final fakeChannel = FakeBatteryChannel(
        DeviceChannelResult.success({
          'level': 75,
          'isCharging': false,
          'chargingType': 'none',
        }),
      );
      final tool = BatteryTool(fakeChannel);

      final result = await tool.execute(const ToolArguments({}));

      expect(result.isSuccess, isTrue);
      final data = result.data as Map<String, dynamic>;
      expect(data['level'], 75);
      expect(data['isCharging'], isFalse);
      expect(data['chargingType'], 'none');
    });

    test('returns full battery level 100 with AC charging', () async {
      final fakeChannel = FakeBatteryChannel(
        DeviceChannelResult.success({
          'level': 100,
          'isCharging': true,
          'chargingType': 'ac',
        }),
      );
      final tool = BatteryTool(fakeChannel);

      final result = await tool.execute(const ToolArguments({}));

      expect(result.isSuccess, isTrue);
      final data = result.data as Map<String, dynamic>;
      expect(data['level'], 100);
      expect(data['isCharging'], isTrue);
      expect(data['chargingType'], 'ac');
    });
  });

  // ── Charging Status Variants ──────────────────────────────────────

  group('BatteryTool execution - charging variants', () {
    test('USB charging type', () async {
      final fakeChannel = FakeBatteryChannel(
        DeviceChannelResult.success({
          'level': 42,
          'isCharging': true,
          'chargingType': 'usb',
        }),
      );
      final tool = BatteryTool(fakeChannel);

      final result = await tool.execute(const ToolArguments({}));

      expect(result.isSuccess, isTrue);
      final data = result.data as Map<String, dynamic>;
      expect(data['chargingType'], 'usb');
      expect(data['isCharging'], isTrue);
    });

    test('wireless charging type', () async {
      final fakeChannel = FakeBatteryChannel(
        DeviceChannelResult.success({
          'level': 88,
          'isCharging': true,
          'chargingType': 'wireless',
        }),
      );
      final tool = BatteryTool(fakeChannel);

      final result = await tool.execute(const ToolArguments({}));

      expect(result.isSuccess, isTrue);
      final data = result.data as Map<String, dynamic>;
      expect(data['chargingType'], 'wireless');
      expect(data['isCharging'], isTrue);
    });

    test('not charging with none type', () async {
      final fakeChannel = FakeBatteryChannel(
        DeviceChannelResult.success({
          'level': 15,
          'isCharging': false,
          'chargingType': 'none',
        }),
      );
      final tool = BatteryTool(fakeChannel);

      final result = await tool.execute(const ToolArguments({}));

      expect(result.isSuccess, isTrue);
      final data = result.data as Map<String, dynamic>;
      expect(data['chargingType'], 'none');
      expect(data['isCharging'], isFalse);
    });
  });

  // ── Platform Unsupported ───────────────────────────────────────────

  group('BatteryTool execution - failure', () {
    test('returns failure when channel returns platformUnsupported',
        () async {
      final fakeChannel = FakeBatteryChannel(
        const DeviceChannelResult.failure(
          'Battery info not available on ios',
          errorCode: 'platformUnsupported',
        ),
      );
      final tool = BatteryTool(fakeChannel);

      final result = await tool.execute(const ToolArguments({}));

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'platformUnsupported');
      expect(result.errorMessage, contains('Battery info not available'));
    });

    test('returns failure when channel returns generic error', () async {
      final fakeChannel = FakeBatteryChannel(
        const DeviceChannelResult.failure(
          'Permission denied',
          errorCode: 'permissionDenied',
        ),
      );
      final tool = BatteryTool(fakeChannel);

      final result = await tool.execute(const ToolArguments({}));

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'permissionDenied');
      expect(result.errorMessage, contains('Permission denied'));
    });

    test('catches unexpected exception and returns internalError', () async {
      final throwingChannel = ThrowingBatteryChannel(
        StateError('battery crash'),
      );
      final tool = BatteryTool(throwingChannel);

      final result = await tool.execute(const ToolArguments({}));

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'internalError');
      expect(result.errorMessage, contains('Battery info error'));
    });

    test('handles null errorMessage from channel gracefully', () async {
      final fakeChannel = FakeBatteryChannel(
        const DeviceChannelResult.failure(
          null,
          errorCode: 'unknown',
        ),
      );
      final tool = BatteryTool(fakeChannel);

      final result = await tool.execute(const ToolArguments({}));

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, 'Battery info request failed');
    });
  });

  // ── Malformed / Unexpected Result ─────────────────────────────────

  group('BatteryTool execution - edge cases', () {
    test('returns success even with empty data map', () async {
      final fakeChannel = FakeBatteryChannel(
        const DeviceChannelResult.success({}),
      );
      final tool = BatteryTool(fakeChannel);

      final result = await tool.execute(const ToolArguments({}));

      // Tool delegates to channel; an empty map is still success.
      expect(result.isSuccess, isTrue);
      final data = result.data as Map<String, dynamic>;
      expect(data, isEmpty);
    });

    test('returns success with extra unexpected keys in data', () async {
      final fakeChannel = FakeBatteryChannel(
        DeviceChannelResult.success({
          'level': 50,
          'isCharging': true,
          'chargingType': 'usb',
          'temperature': 32, // extra key
          'voltage': 4200, // extra key
        }),
      );
      final tool = BatteryTool(fakeChannel);

      final result = await tool.execute(const ToolArguments({}));

      expect(result.isSuccess, isTrue);
      final data = result.data as Map<String, dynamic>;
      expect(data['level'], 50);
      expect(data['temperature'], 32);
    });
  });

  // ── StubDeviceChannel Integration ─────────────────────────────────

  group('BatteryTool with StubDeviceChannel', () {
    test('returns platformUnsupported failure on stub channel', () async {
      final stubChannel = StubDeviceChannel(platformLabel: 'ios');
      final tool = BatteryTool(stubChannel);

      final result = await tool.execute(const ToolArguments({}));

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'platformUnsupported');
      expect(result.errorMessage, contains('not available'));
    });

    test('stub channel includes platform label in error message', () async {
      final stubChannel = StubDeviceChannel(platformLabel: 'web');
      final tool = BatteryTool(stubChannel);

      final result = await tool.execute(const ToolArguments({}));

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('web'));
    });
  });

  // ── ToolRegistry Integration ──────────────────────────────────────

  group('BatteryTool in ToolRegistry', () {
    test('can be registered and retrieved by name', () {
      final registry = ToolRegistry();
      final fakeChannel = FakeBatteryChannel(
        const DeviceChannelResult.success({}),
      );
      final tool = BatteryTool(fakeChannel);

      registry.register(tool);

      expect(registry.has('battery'), isTrue);
      expect(registry.get('battery'), same(tool));
    });

    test('is listed under device category', () {
      final registry = ToolRegistry();
      final fakeChannel = FakeBatteryChannel(
        const DeviceChannelResult.success({}),
      );
      final tool = BatteryTool(fakeChannel);

      registry.register(tool);

      final deviceTools = registry.getByCategory('device');
      expect(deviceTools, hasLength(1));
      expect(deviceTools.first.name, 'battery');
    });

    test('is not dangerous and does not require confirmation', () {
      final registry = ToolRegistry();
      final fakeChannel = FakeBatteryChannel(
        const DeviceChannelResult.success({}),
      );
      final tool = BatteryTool(fakeChannel);

      registry.register(tool);

      expect(registry.dangerous, isEmpty);
      expect(registry.requiringConfirmation, isEmpty);
    });

    test('is allowed by default allowlist', () {
      final registry = ToolRegistry();
      final fakeChannel = FakeBatteryChannel(
        const DeviceChannelResult.success({}),
      );
      final tool = BatteryTool(fakeChannel);

      registry.register(tool);

      expect(registry.isAllowed('battery'), isTrue);
    });

    test('OpenAI schema includes battery function', () {
      final registry = ToolRegistry();
      final fakeChannel = FakeBatteryChannel(
        const DeviceChannelResult.success({}),
      );
      final tool = BatteryTool(fakeChannel);

      registry.register(tool);

      final schemas = registry.openAISchemas;
      expect(schemas, hasLength(1));
      expect(schemas.first['type'], 'function');
      final fn = schemas.first['function'] as Map<String, dynamic>;
      expect(fn['name'], 'battery');
      expect(fn['description'], isNotNull);
    });

    test('executes successfully through registry', () async {
      final registry = ToolRegistry();
      final fakeChannel = FakeBatteryChannel(
        DeviceChannelResult.success({
          'level': 60,
          'isCharging': true,
          'chargingType': 'ac',
        }),
      );
      final tool = BatteryTool(fakeChannel);

      registry.register(tool);

      final retrieved = registry.getOrThrow('battery');
      final result = await retrieved.execute(const ToolArguments({}));

      expect(result.isSuccess, isTrue);
      final data = result.data as Map<String, dynamic>;
      expect(data['level'], 60);
      expect(data['isCharging'], isTrue);
    });

    test('executes with stub channel through registry', () async {
      final registry = ToolRegistry();
      final stubChannel = StubDeviceChannel(platformLabel: 'desktop');
      final tool = BatteryTool(stubChannel);

      registry.register(tool);

      final retrieved = registry.getOrThrow('battery');
      final result = await retrieved.execute(const ToolArguments({}));

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'platformUnsupported');
    });

    test('coexists with DeviceInfoTool in registry', () async {
      final registry = ToolRegistry();
      final fakeChannel = FakeBatteryChannel(
        const DeviceChannelResult.success({}),
      );

      registry.register(BatteryTool(fakeChannel));
      registry.register(DeviceInfoTool(fakeChannel));

      expect(registry.has('battery'), isTrue);
      expect(registry.has('device_info'), isTrue);
      // Both registered under device category
      final deviceTools = registry.getByCategory('device');
      expect(deviceTools.length, 2);
    });
  });
}
