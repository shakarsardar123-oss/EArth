/// device_permission_test.dart
/// AURA Assistant – Step 16: Central Permissions
///
/// Tests for DevicePermission enum (10 values including Step 16 additions).

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/device_integration/domain/models/permission_status.dart';

void main() {
  group('DevicePermission', () {
    test('has exactly 10 values', () {
      expect(DevicePermission.values.length, 10);
    });

    test('contains all original and new values', () {
      expect(DevicePermission.values, containsAll([
        // Original (Step 3)
        DevicePermission.accessibility,
        DevicePermission.overlay,
        DevicePermission.screenCapture,
        // Step 15 additions
        DevicePermission.microphone,
        // Step 16 additions
        DevicePermission.camera,
        DevicePermission.storage,
        DevicePermission.notification,
        DevicePermission.batteryOptimization,
        DevicePermission.assistant,
        DevicePermission.location,
      ]));
    });

    test('each value has correct name', () {
      expect(DevicePermission.accessibility.name, 'accessibility');
      expect(DevicePermission.overlay.name, 'overlay');
      expect(DevicePermission.screenCapture.name, 'screenCapture');
      expect(DevicePermission.microphone.name, 'microphone');
      expect(DevicePermission.camera.name, 'camera');
      expect(DevicePermission.storage.name, 'storage');
      expect(DevicePermission.notification.name, 'notification');
      expect(DevicePermission.batteryOptimization.name, 'batteryOptimization');
      expect(DevicePermission.assistant.name, 'assistant');
      expect(DevicePermission.location.name, 'location');
    });
  });
}
