/// feature_permission_adapters_test.dart
/// AURA Assistant – Step 16: Central Permissions
///
/// Structural tests for feature-permission adapters.
/// No Flutter SDK — structural/mock tests only.

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/central_permissions/adapters/voice_screen_adapter.dart';
import 'package:aura_assistant/features/central_permissions/adapters/vision_adapter.dart';
import 'package:aura_assistant/features/central_permissions/adapters/screen_capture_adapter.dart';
import 'package:aura_assistant/features/central_permissions/adapters/floating_overlay_adapter.dart';
import 'package:aura_assistant/features/central_permissions/adapters/assistant_integration_adapter.dart';
import 'package:aura_assistant/features/central_permissions/adapters/device_integration_adapter.dart';
import 'package:aura_assistant/features/central_permissions/adapters/file_storage_adapter.dart';
import 'package:aura_assistant/features/central_permissions/adapters/notifications_adapter.dart';
import 'package:aura_assistant/features/central_permissions/adapters/foreground_service_adapter.dart';
import 'package:aura_assistant/features/central_permissions/adapters/location_services_adapter.dart';
import 'package:aura_assistant/features/device_integration/domain/models/permission_status.dart';

void main() {
  group('Feature-Permission Adapters', () {
    test('VoiceScreenPermissionAdapter maps to microphone', () {
      final adapter = VoiceScreenPermissionAdapter();
      expect(adapter.permissions, contains(DevicePermission.microphone));
    });

    test('VisionPermissionAdapter maps to camera', () {
      final adapter = VisionPermissionAdapter();
      expect(adapter.permissions, contains(DevicePermission.camera));
    });

    test('ScreenCapturePermissionAdapter maps to screenCapture', () {
      final adapter = ScreenCapturePermissionAdapter();
      expect(adapter.permissions, contains(DevicePermission.screenCapture));
    });

    test('FloatingOverlayPermissionAdapter maps to overlay', () {
      final adapter = FloatingOverlayPermissionAdapter();
      expect(adapter.permissions, contains(DevicePermission.overlay));
    });

    test('AssistantPermissionAdapter maps to assistant', () {
      final adapter = AssistantPermissionAdapter();
      expect(adapter.permissions, contains(DevicePermission.assistant));
    });

    test('DeviceIntegrationPermissionAdapter maps to accessibility+overlay+screenCapture', () {
      final adapter = DeviceIntegrationPermissionAdapter();
      expect(adapter.permissions, contains(DevicePermission.accessibility));
      expect(adapter.permissions, contains(DevicePermission.overlay));
      expect(adapter.permissions, contains(DevicePermission.screenCapture));
    });

    test('FileStoragePermissionAdapter maps to storage', () {
      final adapter = FileStoragePermissionAdapter();
      expect(adapter.permissions, contains(DevicePermission.storage));
    });

    test('NotificationPermissionAdapter maps to notification', () {
      final adapter = NotificationPermissionAdapter();
      expect(adapter.permissions, contains(DevicePermission.notification));
    });

    test('ForegroundServicePermissionAdapter maps to batteryOptimization', () {
      final adapter = ForegroundServicePermissionAdapter();
      expect(adapter.permissions, contains(DevicePermission.batteryOptimization));
    });

    test('LocationPermissionAdapter maps to location', () {
      final adapter = LocationPermissionAdapter();
      expect(adapter.permissions, contains(DevicePermission.location));
    });

    test('all adapters expose a featureName', () {
      final adapters = [
        VoiceScreenPermissionAdapter(),
        VisionPermissionAdapter(),
        ScreenCapturePermissionAdapter(),
        FloatingOverlayPermissionAdapter(),
        AssistantPermissionAdapter(),
        DeviceIntegrationPermissionAdapter(),
        FileStoragePermissionAdapter(),
        NotificationPermissionAdapter(),
        ForegroundServicePermissionAdapter(),
        LocationPermissionAdapter(),
      ];
      for (final adapter in adapters) {
        expect(adapter.featureName, isA<String>());
        expect(adapter.featureName, isNotEmpty);
      }
    });

    test('no adapter returns empty permissions list', () {
      final adapters = [
        VoiceScreenPermissionAdapter(),
        VisionPermissionAdapter(),
        ScreenCapturePermissionAdapter(),
        FloatingOverlayPermissionAdapter(),
        AssistantPermissionAdapter(),
        DeviceIntegrationPermissionAdapter(),
        FileStoragePermissionAdapter(),
        NotificationPermissionAdapter(),
        ForegroundServicePermissionAdapter(),
        LocationPermissionAdapter(),
      ];
      for (final adapter in adapters) {
        expect(adapter.permissions, isNotEmpty,
            reason: '${adapter.featureName} has empty permissions list');
      }
    });
  });
}
