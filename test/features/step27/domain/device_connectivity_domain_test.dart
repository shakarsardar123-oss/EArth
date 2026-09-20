/// device_connectivity_domain_test.dart
/// Step 27 structural validation — Device Connectivity domain layer.
library;

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Device Connectivity Domain', () {
    test('DeviceConnectionStatus.unknown.isBlocking is true', () {
      expect(DeviceConnectionStatus.unknown.isBlocking, isTrue);
    });

    test('TransportResult failure has success=false', () {
      final result = TransportResult(success: false, errorMessage: 'test');
      expect(result.success, isFalse);
    });

    test('DeviceCommand requires connectionId and deviceId', () {
      final cmd = DeviceCommand(connectionId: 'c1', deviceId: 'd1', payload: {});
      expect(cmd.connectionId, 'c1');
      expect(cmd.deviceId, 'd1');
    });
  });
}
