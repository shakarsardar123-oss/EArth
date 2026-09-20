/// Tests for PermissionStatus, DevicePermission, PermissionResult,
/// and PermissionManager abstract.
/// Covers: enum values, PermissionResult.allGranted/denied/hasPermanentlyDenied.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/device_integration/domain/models/permission_status.dart';

void main() {
  // ─── PermissionStatus ────────────────────────────────────────────
  group('PermissionStatus', () {
    test('has all four statuses', () {
      expect(PermissionStatus.values.length, 4);
      expect(PermissionStatus.values, contains(PermissionStatus.granted));
      expect(PermissionStatus.values, contains(PermissionStatus.denied));
      expect(PermissionStatus.values,
          contains(PermissionStatus.notRequested));
      expect(PermissionStatus.values,
          contains(PermissionStatus.permanentlyDenied));
    });
  });

  // ─── DevicePermission ─────────────────────────────────────────────
  group('DevicePermission', () {
    test('has all three permissions', () {
      expect(DevicePermission.values.length, 3);
      expect(DevicePermission.values,
          contains(DevicePermission.accessibility));
      expect(DevicePermission.values,
          contains(DevicePermission.overlay));
      expect(DevicePermission.values,
          contains(DevicePermission.screenCapture));
    });
  });

  // ─── PermissionResult ────────────────────────────────────────────
  group('PermissionResult', () {
    test('allGranted is true when all statuses are granted', () {
      final result = PermissionResult(statuses: {
        DevicePermission.accessibility: PermissionStatus.granted,
        DevicePermission.overlay: PermissionStatus.granted,
        DevicePermission.screenCapture: PermissionStatus.granted,
      });
      expect(result.allGranted, isTrue);
      expect(result.denied, isEmpty);
      expect(result.hasPermanentlyDenied, isFalse);
    });

    test('allGranted is false when any status is denied', () {
      final result = PermissionResult(statuses: {
        DevicePermission.accessibility: PermissionStatus.granted,
        DevicePermission.overlay: PermissionStatus.denied,
        DevicePermission.screenCapture: PermissionStatus.granted,
      });
      expect(result.allGranted, isFalse);
      expect(result.denied, isNotEmpty);
    });

    test('denied list includes only denied permissions', () {
      final result = PermissionResult(statuses: {
        DevicePermission.accessibility: PermissionStatus.granted,
        DevicePermission.overlay: PermissionStatus.denied,
        DevicePermission.screenCapture: PermissionStatus.denied,
      });
      expect(result.denied.length, 2);
      expect(result.denied, contains(DevicePermission.overlay));
      expect(result.denied, contains(DevicePermission.screenCapture));
      expect(result.denied, isNot(contains(DevicePermission.accessibility)));
    });

    test('hasPermanentlyDenied is true when any status is permanentlyDenied', () {
      final result = PermissionResult(statuses: {
        DevicePermission.accessibility: PermissionStatus.permanentlyDenied,
        DevicePermission.overlay: PermissionStatus.granted,
        DevicePermission.screenCapture: PermissionStatus.granted,
      });
      expect(result.hasPermanentlyDenied, isTrue);
      expect(result.denied, contains(DevicePermission.accessibility));
    });

    test('hasPermanentlyDenied is false when no status is permanentlyDenied', () {
      final result = PermissionResult(statuses: {
        DevicePermission.accessibility: PermissionStatus.denied,
        DevicePermission.overlay: PermissionStatus.granted,
        DevicePermission.screenCapture: PermissionStatus.granted,
      });
      expect(result.hasPermanentlyDenied, isFalse);
    });

    test('notRequested is treated as not denied', () {
      final result = PermissionResult(statuses: {
        DevicePermission.accessibility: PermissionStatus.notRequested,
        DevicePermission.overlay: PermissionStatus.granted,
        DevicePermission.screenCapture: PermissionStatus.granted,
      });
      expect(result.denied, isNot(contains(DevicePermission.accessibility)));
      expect(result.allGranted, isFalse);
    });
  });
}
