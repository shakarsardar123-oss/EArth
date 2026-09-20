/// Tests for AndroidDeviceExecutor.
/// Covers: isPlatformSupported, execute on Android vs non-Android, cancel.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/device_integration/infrastructure/android_device_executor.dart';
import 'package:aura_assistant/features/device_integration/domain/entities/device_action.dart';
import 'package:aura_assistant/features/device_integration/domain/models/device_integration_failure.dart';
import 'package:aura_assistant/core/errors/result.dart';

void main() {
  // ─── AndroidDeviceExecutor on Android ────────────────────────────
  group('AndroidDeviceExecutor on Android', () {
    late AndroidDeviceExecutor executor;

    setUp(() {
      executor = AndroidDeviceExecutor(isAndroid: true);
    });

    test('isPlatformSupported returns true on Android', () {
      expect(executor.isPlatformSupported, isTrue);
    });

    test('execute returns success on Android', () async {
      final action = DeviceAction.tap(
        targetPoint: const NormalizedPoint(x: 0.5, y: 0.5),
      );
      final result = await executor.execute(action);
      expect(result.isFailure, isFalse);
    });

    test('execute swipe returns success on Android', () async {
      final action = DeviceAction.swipe(
        swipeStart: const NormalizedPoint(x: 0.5, y: 0.8),
        swipeEnd: const NormalizedPoint(x: 0.5, y: 0.2),
      );
      final result = await executor.execute(action);
      expect(result.isFailure, isFalse);
    });

    test('execute with frame dimensions returns success on Android', () async {
      final action = DeviceAction.tap(
        targetPoint: const NormalizedPoint(x: 0.5, y: 0.5),
      );
      final result = await executor.execute(
        action,
        frameWidth: 1080,
        frameHeight: 1920,
      );
      expect(result.isFailure, isFalse);
    });

    test('cancel does not throw on Android', () async {
      await executor.cancel();
      // No exception means pass
    });
  });

  // ─── AndroidDeviceExecutor on non-Android ─────────────────────────
  group('AndroidDeviceExecutor on non-Android', () {
    late AndroidDeviceExecutor executor;

    setUp(() {
      executor = AndroidDeviceExecutor(isAndroid: false);
    });

    test('isPlatformSupported returns false on non-Android', () {
      expect(executor.isPlatformSupported, isFalse);
    });

    test('execute returns failure on non-Android', () async {
      final action = DeviceAction.tap(
        targetPoint: const NormalizedPoint(x: 0.5, y: 0.5),
      );
      final result = await executor.execute(action);
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull!.phase,
          DeviceIntegrationFailurePhase.execution);
    });

    test('execute back returns failure on non-Android', () async {
      final action = DeviceAction.back();
      final result = await executor.execute(action);
      expect(result.isFailure, isTrue);
    });

    test('cancel does not throw on non-Android', () async {
      await executor.cancel();
    });
  });
}
