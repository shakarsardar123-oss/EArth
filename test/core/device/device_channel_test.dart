import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/core/device/device_channel.dart';
import 'package:aura_assistant/core/device/android_device_channel.dart';
import 'package:aura_assistant/core/device/stub_device_channel.dart';

void main() {
  group('DeviceChannelResult', () {
    test('success result holds data and is marked successful', () {
      const result = DeviceChannelResult.success({'brand': 'Samsung'});

      expect(result.isSuccess, isTrue);
      expect(result.data, isNotNull);
      expect(result.data!['brand'], 'Samsung');
      expect(result.errorMessage, isNull);
      expect(result.errorCode, isNull);
    });

    test('failure result holds error info and is not successful', () {
      const result = DeviceChannelResult.failure(
        'Something went wrong',
        errorCode: 'platformUnsupported',
      );

      expect(result.isSuccess, isFalse);
      expect(result.data, isNull);
      expect(result.errorMessage, 'Something went wrong');
      expect(result.errorCode, 'platformUnsupported');
    });

    test('toString formats success and failure correctly', () {
      const success = DeviceChannelResult.success({'key': 'val'});
      const failure = DeviceChannelResult.failure('err', errorCode: 'code');

      expect(success.toString(), contains('success'));
      expect(failure.toString(), contains('failure'));
      expect(failure.toString(), contains('err'));
    });
  });

  group('StubDeviceChannel', () {
    late StubDeviceChannel stub;

    setUp(() {
      stub = StubDeviceChannel(platformLabel: 'test');
    });

    test('getDeviceInfo returns platformUnsupported failure', () async {
      final result = await stub.getDeviceInfo();

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'platformUnsupported');
      expect(result.errorMessage, contains('getDeviceInfo'));
      expect(result.errorMessage, contains('test'));
    });

    test('getBatteryInfo returns platformUnsupported failure', () async {
      final result = await stub.getBatteryInfo();

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'platformUnsupported');
    });

    test('getNetworkInfo returns platformUnsupported failure', () async {
      final result = await stub.getNetworkInfo();

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'platformUnsupported');
    });

    test('launchApp returns platformUnsupported failure', () async {
      final result = await stub.launchApp('com.example.app');

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'platformUnsupported');
    });

    test('openSystemSettings returns platformUnsupported failure', () async {
      final result = await stub.openSystemSettings('wifi');

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'platformUnsupported');
    });

    test('launchUrl returns platformUnsupported failure', () async {
      final result = await stub.launchUrl('https://example.com');

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'platformUnsupported');
    });

    test('default platformLabel is "unsupported"', () async {
      final defaultStub = StubDeviceChannel();
      final result = await defaultStub.getDeviceInfo();

      expect(result.errorMessage, contains('unsupported'));
    });
  });

  group('AndroidDeviceChannel', () {
    test('implements DeviceChannel', () {
      // Verify the type relationship without actually invoking
      // the MethodChannel (which would fail in a unit test).
      expect(AndroidDeviceChannel(), isA<DeviceChannel>());
    });

    test('DeviceMethodNames contains all expected constants', () {
      expect(DeviceMethodNames.getDeviceInfo, 'getDeviceInfo');
      expect(DeviceMethodNames.getBatteryInfo, 'getBatteryInfo');
      expect(DeviceMethodNames.getNetworkInfo, 'getNetworkInfo');
      expect(DeviceMethodNames.launchApp, 'launchApp');
      expect(DeviceMethodNames.openSystemSettings, 'openSystemSettings');
      expect(DeviceMethodNames.launchUrl, 'launchUrl');
    });
  });
}
