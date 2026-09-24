// Unit tests for the AssistantMethodChannel bridge.
//
// These verify the Dart side correctly interprets the values returned by the
// native (Kotlin) assistant-integration MethodChannel and maps them to the
// domain result states used by the UI:
//   unsupported / available / alreadyDefault(active) / denied(stays available)
//   / error / requestStarted(openAssistantSettings).
//
// The native side cannot be exercised here (no Android runtime), so we mock
// the platform channel and assert the pure Dart mapping. This is a STATIC/
// unit-level test, NOT a proof that RoleManager behaves on a real device.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:texo/core/errors/result.dart';
import 'package:texo/features/assistant_integration/domain/entities/assistant_status.dart';
import 'package:texo/features/assistant_integration/infrastructure/assistant_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.aura.assistant/assistant_integration');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  // Installs a fake native handler. [availability] is returned for
  // getAssistantAvailability; [apiLevel] for getAndroidApiLevel; if
  // [throwOn] matches a method name a PlatformException is raised.
  void mockNative({
    String availability = 'available',
    int apiLevel = 33,
    String? throwOn,
    bool openSettingsFails = false,
  }) {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == throwOn) {
        throw PlatformException(code: 'BOOM', message: 'native failure');
      }
      switch (call.method) {
        case 'getAssistantAvailability':
          return availability;
        case 'getAndroidApiLevel':
          return apiLevel;
        case 'openAssistantSettings':
          if (openSettingsFails) {
            throw PlatformException(
                code: 'OPEN_SETTINGS_FAILED', message: 'no settings activity');
          }
          return <String, Object?>{'launched': true, 'route': 'voice_input_settings'};
        case 'isAssistantRoleAvailable':
          return availability != 'unsupported';
        default:
          return null;
      }
    });
  }

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  group('AssistantMethodChannel.detectStatus', () {
    test('maps "unsupported" → unsupported (cannot request)', () async {
      mockNative(availability: 'unsupported', apiLevel: 26);
      final r = await AssistantMethodChannel().detectStatus();
      expect(r.isSuccess, isTrue);
      final s = (r as Success).value as AssistantStatus;
      expect(s.availability, AssistantAvailability.unsupported);
      expect(s.isUnsupported, isTrue);
      expect(s.canRequestDefault, isFalse);
      expect(s.isAuraDefault, isFalse);
      expect(s.androidApiLevel, 26);
    });

    test('maps "available" → available (can request, not default)', () async {
      mockNative(availability: 'available', apiLevel: 34);
      final r = await AssistantMethodChannel().detectStatus();
      expect(r.isSuccess, isTrue);
      final s = (r as Success).value as AssistantStatus;
      expect(s.availability, AssistantAvailability.available);
      expect(s.canRequestDefault, isTrue);
      expect(s.isAuraDefault, isFalse);
    });

    test('maps "active" → already default assistant', () async {
      mockNative(availability: 'active', apiLevel: 34);
      final r = await AssistantMethodChannel().detectStatus();
      expect(r.isSuccess, isTrue);
      final s = (r as Success).value as AssistantStatus;
      expect(s.availability, AssistantAvailability.active);
      expect(s.isAuraDefault, isTrue);
      expect(s.canRequestDefault, isFalse);
    });

    test('unknown native value falls back to unsupported', () async {
      mockNative(availability: 'wat', apiLevel: 34);
      final r = await AssistantMethodChannel().detectStatus();
      expect(r.isSuccess, isTrue);
      final s = (r as Success).value as AssistantStatus;
      expect(s.availability, AssistantAvailability.unsupported);
    });

    test('native error → failure result (never fake success)', () async {
      mockNative(throwOn: 'getAssistantAvailability');
      final r = await AssistantMethodChannel().detectStatus();
      expect(r.isError, isTrue);
    });
  });

  group('AssistantMethodChannel.openAssistantSettings', () {
    test('success when a settings screen was launched', () async {
      mockNative();
      final r = await AssistantMethodChannel().openAssistantSettings();
      expect(r.isSuccess, isTrue);
    });

    test('failure when native could not resolve any settings screen', () async {
      mockNative(openSettingsFails: true);
      final r = await AssistantMethodChannel().openAssistantSettings();
      expect(r.isError, isTrue);
    });
  });

  group('AssistantMethodChannel.isAssistantRoleSupported', () {
    test('true when platform reports a non-unsupported availability', () async {
      mockNative(availability: 'available');
      final r = await AssistantMethodChannel().isAssistantRoleSupported();
      expect((r as Success).value, isTrue);
    });

    test('false when platform reports unsupported', () async {
      mockNative(availability: 'unsupported');
      final r = await AssistantMethodChannel().isAssistantRoleSupported();
      expect((r as Success).value, isFalse);
    });
  });
}
