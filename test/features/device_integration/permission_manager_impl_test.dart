/// Tests for StubPermissionManager.
/// Covers: autoGrant, setStatus, checkStatus, request, checkAll, requestAll, openSettings.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/device_integration/infrastructure/permission_manager_impl.dart';
import 'package:aura_assistant/features/device_integration/domain/models/permission_status.dart';
import 'package:aura_assistant/core/errors/result.dart';

void main() {
  // ─── StubPermissionManager defaults ───────────────────────────────
  group('StubPermissionManager defaults', () {
    test('autoGrantOnRequest defaults to true', () {
      final mgr = StubPermissionManager();
      expect(mgr.autoGrantOnRequest, isTrue);
    });

    test('initial statuses are notRequested for all permissions', () async {
      final mgr = StubPermissionManager();
      final status = await mgr.checkStatus(DevicePermission.accessibility);
      expect(status, PermissionStatus.notRequested);
    });
  });

  // ─── checkStatus with initialStatuses ────────────────────────────
  group('StubPermissionManager.checkStatus', () {
    test('returns configured initial status', () async {
      final mgr = StubPermissionManager(
        initialStatuses: {
          DevicePermission.accessibility: PermissionStatus.granted,
          DevicePermission.overlay: PermissionStatus.denied,
        },
      );
      expect(
        await mgr.checkStatus(DevicePermission.accessibility),
        PermissionStatus.granted,
      );
      expect(
        await mgr.checkStatus(DevicePermission.overlay),
        PermissionStatus.denied,
      );
    });

    test('returns notRequested for unconfigured permission', () async {
      final mgr = StubPermissionManager(
        initialStatuses: {
          DevicePermission.accessibility: PermissionStatus.granted,
        },
      );
      expect(
        await mgr.checkStatus(DevicePermission.screenCapture),
        PermissionStatus.notRequested,
      );
    });
  });

  // ─── setStatus ───────────────────────────────────────────────────
  group('StubPermissionManager.setStatus', () {
    test('setStatus updates the status', () async {
      final mgr = StubPermissionManager();
      mgr.setStatus(DevicePermission.accessibility, PermissionStatus.granted);
      expect(
        await mgr.checkStatus(DevicePermission.accessibility),
        PermissionStatus.granted,
      );
    });

    test('setStatus can set permanentlyDenied', () async {
      final mgr = StubPermissionManager();
      mgr.setStatus(
        DevicePermission.overlay,
        PermissionStatus.permanentlyDenied,
      );
      expect(
        await mgr.checkStatus(DevicePermission.overlay),
        PermissionStatus.permanentlyDenied,
      );
    });
  });

  // ─── request with autoGrant ──────────────────────────────────────
  group('StubPermissionManager.request autoGrant', () {
    test('autoGrantOnRequest=true grants permissions on request', () async {
      final mgr = StubPermissionManager(autoGrantOnRequest: true);
      final result = await mgr.request([DevicePermission.accessibility]);
      expect(result.allGranted, isTrue);
    });

    test('autoGrantOnRequest=true updates internal statuses', () async {
      final mgr = StubPermissionManager(autoGrantOnRequest: true);
      await mgr.request([DevicePermission.accessibility]);
      expect(
        await mgr.checkStatus(DevicePermission.accessibility),
        PermissionStatus.granted,
      );
    });
  });

  // ─── request with autoGrant=false ────────────────────────────────
  group('StubPermissionManager.request autoGrant=false', () {
    test('autoGrantOnRequest=false denies permissions on request', () async {
      final mgr = StubPermissionManager(autoGrantOnRequest: false);
      final result = await mgr.request([DevicePermission.accessibility]);
      expect(result.allGranted, isFalse);
      expect(result.denied, contains(DevicePermission.accessibility));
    });
  });

  // ─── checkAll ───────────────────────────────────────────────────
  group('StubPermissionManager.checkAll', () {
    test('checkAll returns all configured statuses', () async {
      final mgr = StubPermissionManager(
        initialStatuses: {
          DevicePermission.accessibility: PermissionStatus.granted,
          DevicePermission.overlay: PermissionStatus.denied,
          DevicePermission.screenCapture: PermissionStatus.notRequested,
        },
      );
      final result = await mgr.checkAll();
      expect(result.allGranted, isFalse);
      expect(result.denied, contains(DevicePermission.overlay));
    });
  });

  // ─── requestAll ─────────────────────────────────────────────────
  group('StubPermissionManager.requestAll', () {
    test('requestAll with autoGrant grants all', () async {
      final mgr = StubPermissionManager(autoGrantOnRequest: true);
      final result = await mgr.requestAll();
      expect(result.allGranted, isTrue);
    });

    test('requestAll without autoGrant denies all', () async {
      final mgr = StubPermissionManager(autoGrantOnRequest: false);
      final result = await mgr.requestAll();
      expect(result.allGranted, isFalse);
    });
  });

  // ─── openSettings ───────────────────────────────────────────────
  group('StubPermissionManager.openSettings', () {
    test('openSettings returns success', () async {
      final mgr = StubPermissionManager();
      final result = await mgr.openSettings();
      expect(result.isFailure, isFalse);
    });
  });
}
