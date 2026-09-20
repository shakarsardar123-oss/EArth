import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/core/device/device_channel.dart';
import 'package:aura_assistant/core/device/stub_device_channel.dart';
import 'package:aura_assistant/core/tools/device/device_info_tool.dart';
import 'package:aura_assistant/core/tools/tool_arguments.dart';
import 'package:aura_assistant/core/tools/tool_result.dart';
import 'package:aura_assistant/core/tools/tool_registry.dart';
import 'package:aura_assistant/core/agent/agent_confirmation_manager.dart';

/// A fake [DeviceChannel] that returns configurable results.
class FakeDeviceChannel implements DeviceChannel {
  final DeviceChannelResult _infoResult;

  FakeDeviceChannel(this._infoResult);

  @override
  Future<DeviceChannelResult> getDeviceInfo() async => _infoResult;

  @override
  Future<DeviceChannelResult> getBatteryInfo() async =>
      DeviceChannelResult.failure('not used', errorCode: 'unused');

  @override
  Future<DeviceChannelResult> getNetworkInfo() async =>
      DeviceChannelResult.failure('not used', errorCode: 'unused');

  @override
  Future<DeviceChannelResult> launchApp(String packageId) async =>
      DeviceChannelResult.failure('not used', errorCode: 'unused');

  @override
  Future<DeviceChannelResult> openSystemSettings(String settingsAction) async =>
      DeviceChannelResult.failure('not used', errorCode: 'unused');

  @override
  Future<DeviceChannelResult> launchUrl(String url) async =>
      DeviceChannelResult.failure('not used', errorCode: 'unused');
}

/// A [DeviceChannel] that throws on every call.
class ThrowingDeviceChannel implements DeviceChannel {
  final Object exception;

  ThrowingDeviceChannel(this.exception);

  @override
  Future<DeviceChannelResult> getDeviceInfo() async => throw exception;

  @override
  Future<DeviceChannelResult> getBatteryInfo() async => throw exception;

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
  group('DeviceInfoTool', () {
    test('definition metadata is correct', () {
      final fakeChannel = FakeDeviceChannel(
        const DeviceChannelResult.success({}),
      );
      final tool = DeviceInfoTool(fakeChannel);

      expect(tool.name, 'device_info');
      expect(tool.definition.category, 'device');
      expect(tool.definition.isDangerous, isFalse);
      expect(tool.definition.requiresConfirmation, isFalse);
      expect(tool.definition.permissionRequirements, isEmpty);
      expect(tool.definition.tags, contains('device'));
    });

    test('definition includes Kurdish Sorani description', () {
      final fakeChannel = FakeDeviceChannel(
        const DeviceChannelResult.success({}),
      );
      final tool = DeviceInfoTool(fakeChannel);

      // Kurdish Sorani description should be present
      expect(tool.description, contains('زانیاری ئامێر'));
    });

    test('definition includes Kurdish Sorani tags', () {
      final fakeChannel = FakeDeviceChannel(
        const DeviceChannelResult.success({}),
      );
      final tool = DeviceInfoTool(fakeChannel);

      expect(tool.definition.tags, contains('ئامێر'));
      expect(tool.definition.tags, contains('زانیاری'));
    });

    test('definition risk level is none', () {
      final fakeChannel = FakeDeviceChannel(
        const DeviceChannelResult.success({}),
      );
      final tool = DeviceInfoTool(fakeChannel);

      expect(tool.definition.riskLevel, ToolRiskLevel.none);
    });

    test('returns success with device data from channel', () async {
      final deviceData = <String, dynamic>{
        'brand': 'Google',
        'model': 'Pixel 8',
        'manufacturer': 'Google',
        'androidVersion': '14',
        'sdkInt': 34,
        'device': 'husky',
        'isPhysicalDevice': true,
        'board': 'shiba',
        'hardware': 'tensor_g3',
      };

      final fakeChannel = FakeDeviceChannel(
        DeviceChannelResult.success(deviceData),
      );
      final tool = DeviceInfoTool(fakeChannel);

      final result = await tool.execute(
        const ToolArguments({}),
      );

      expect(result.isSuccess, isTrue);
      expect(result.data, isA<Map<String, dynamic>>());
      final data = result.data as Map<String, dynamic>;
      expect(data['brand'], 'Google');
      expect(data['model'], 'Pixel 8');
      expect(data['sdkInt'], 34);
    });

    test('success result includes all expected device fields', () async {
      final deviceData = <String, dynamic>{
        'brand': 'Samsung',
        'model': 'Galaxy S24',
        'manufacturer': 'Samsung',
        'androidVersion': '14',
        'sdkInt': 34,
        'device': 'e3q',
        'isPhysicalDevice': true,
        'board': 's5e9925',
        'hardware': 'qcom',
      };

      final fakeChannel = FakeDeviceChannel(
        DeviceChannelResult.success(deviceData),
      );
      final tool = DeviceInfoTool(fakeChannel);

      final result = await tool.execute(
        const ToolArguments({}),
      );

      final data = result.data as Map<String, dynamic>;
      expect(data, containsPair('brand', 'Samsung'));
      expect(data, containsPair('model', 'Galaxy S24'));
      expect(data, containsPair('manufacturer', 'Samsung'));
      expect(data, containsPair('androidVersion', '14'));
      expect(data, containsPair('sdkInt', 34));;
      expect(data, containsPair('device', 'e3q'));
      expect(data, containsPair('isPhysicalDevice', isTrue));
      expect(data, containsPair('board', 's5e9925'));
      expect(data, containsPair('hardware', 'qcom'));
    });

    test('returns failure when channel returns platformUnsupported', () async {
      final fakeChannel = FakeDeviceChannel(
        const DeviceChannelResult.failure(
          'Not available on ios',
          errorCode: 'platformUnsupported',
        ),
      );
      final tool = DeviceInfoTool(fakeChannel);

      final result = await tool.execute(
        const ToolArguments({}),
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'platformUnsupported');
      expect(result.errorMessage, contains('Not available'));
    });

    test('returns failure when channel returns generic error', () async {
      final fakeChannel = FakeDeviceChannel(
        const DeviceChannelResult.failure(
          'Permission denied',
          errorCode: 'permissionDenied',
        ),
      );
      final tool = DeviceInfoTool(fakeChannel);

      final result = await tool.execute(
        const ToolArguments({}),
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'permissionDenied');
    });

    test('catches unexpected exception and returns internalError', () async {
      final throwingChannel = ThrowingDeviceChannel(
        StateError('boom'),
      );
      final tool = DeviceInfoTool(throwingChannel);

      final result = await tool.execute(
        const ToolArguments({}),
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'internalError');
      expect(result.errorMessage, contains('Device info error'));
    });

    test('handles null errorMessage from channel gracefully', () async {
      // Edge case: isSuccess is false but errorMessage is null
      final fakeChannel = FakeDeviceChannel(
        const DeviceChannelResult.failure(
          null,
          errorCode: 'unknown',
        ),
      );
      final tool = DeviceInfoTool(fakeChannel);

      final result = await tool.execute(
        const ToolArguments({}),
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, 'Device info request failed');
    });
  });

  group('DeviceInfoTool with StubDeviceChannel', () {
    test('returns platformUnsupported failure on stub channel', () async {
      final stubChannel = StubDeviceChannel(platformLabel: 'ios');
      final tool = DeviceInfoTool(stubChannel);

      final result = await tool.execute(
        const ToolArguments({}),
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'platformUnsupported');
      expect(result.errorMessage, contains('not available'));
    });

    test('stub channel includes platform label in error message', () async {
      final stubChannel = StubDeviceChannel(platformLabel: 'web');
      final tool = DeviceInfoTool(stubChannel);

      final result = await tool.execute(
        const ToolArguments({}),
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('web'));
    });
  });

  group('DeviceInfoTool in ToolRegistry', () {
    test('can be registered and retrieved by name', () {
      final registry = ToolRegistry();
      final fakeChannel = FakeDeviceChannel(
        const DeviceChannelResult.success({}),
      );
      final tool = DeviceInfoTool(fakeChannel);

      registry.register(tool);

      expect(registry.has('device_info'), isTrue);
      expect(registry.get('device_info'), same(tool));
    });

    test('is listed under device category', () {
      final registry = ToolRegistry();
      final fakeChannel = FakeDeviceChannel(
        const DeviceChannelResult.success({}),
      );
      final tool = DeviceInfoTool(fakeChannel);

      registry.register(tool);

      final deviceTools = registry.getByCategory('device');
      expect(deviceTools, hasLength(1));
      expect(deviceTools.first.name, 'device_info');
    });

    test('is not dangerous and does not require confirmation', () {
      final registry = ToolRegistry();
      final fakeChannel = FakeDeviceChannel(
        const DeviceChannelResult.success({}),
      );
      final tool = DeviceInfoTool(fakeChannel);

      registry.register(tool);

      expect(registry.dangerous, isEmpty);
      expect(registry.requiringConfirmation, isEmpty);
    });

    test('is allowed by default allowlist', () {
      final registry = ToolRegistry();
      final fakeChannel = FakeDeviceChannel(
        const DeviceChannelResult.success({}),
      );
      final tool = DeviceInfoTool(fakeChannel);

      registry.register(tool);

      expect(registry.isAllowed('device_info'), isTrue);
    });

    test('OpenAI schema includes device_info function', () {
      final registry = ToolRegistry();
      final fakeChannel = FakeDeviceChannel(
        const DeviceChannelResult.success({}),
      );
      final tool = DeviceInfoTool(fakeChannel);

      registry.register(tool);

      final schemas = registry.openAISchemas;
      expect(schemas, hasLength(1));
      expect(schemas.first['type'], 'function');
      final fn = schemas.first['function'] as Map<String, dynamic>;
      expect(fn['name'], 'device_info');
      expect(fn['description'], isNotNull);
    });

    test('executes successfully through registry', () async {
      final registry = ToolRegistry();
      final deviceData = <String, dynamic>{
        'brand': 'Xiaomi',
        'model': '14 Ultra',
        'manufacturer': 'Xiaomi',
        'androidVersion': '14',
        'sdkInt': 34,
        'device': 'nuwa',
        'isPhysicalDevice': true,
        'board': 'taro',
        'hardware': 'qcom',
      };
      final fakeChannel = FakeDeviceChannel(
        DeviceChannelResult.success(deviceData),
      );
      final tool = DeviceInfoTool(fakeChannel);

      registry.register(tool);

      final retrieved = registry.getOrThrow('device_info');
      final result = await retrieved.execute(
        const ToolArguments({}),
      );

      expect(result.isSuccess, isTrue);
      final data = result.data as Map<String, dynamic>;
      expect(data['brand'], 'Xiaomi');
      expect(data['model'], '14 Ultra');
    });

    test('executes with stub channel through registry', () async {
      final registry = ToolRegistry();
      final stubChannel = StubDeviceChannel(platformLabel: 'desktop');
      final tool = DeviceInfoTool(stubChannel);

      registry.register(tool);

      final retrieved = registry.getOrThrow('device_info');
      final result = await retrieved.execute(
        const ToolArguments({}),
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'platformUnsupported');
    });
  });
}
