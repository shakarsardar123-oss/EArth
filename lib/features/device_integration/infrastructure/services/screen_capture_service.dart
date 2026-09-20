/// screen_capture_service.dart
///
/// Abstraction for capturing a device screen and the data types produced.
///
/// RECOVERED in P1-RECOVERY step R2 from the behaviour pinned by
/// `test/features/device_integration/target_resolver_test.dart` and
/// `test/features/device_integration/action_verifier_test.dart`.
library;

import 'dart:typed_data';

/// A single frame captured from the device screen.
///
/// Feature-local type; the core layer has its own `CapturedFrame` with
/// `bytes: Uint8List` + `timestamp: int`. R3 adapters will map between them.
class CapturedFrame {
  const CapturedFrame({
    required this.imageBytes,
    required this.width,
    required this.height,
    required this.timestamp,
  });

  /// Raw PNG/JPEG bytes of the screenshot.
  final Uint8List imageBytes;

  /// Width of the captured frame in pixels.
  final int width;

  /// Height of the captured frame in pixels.
  final int height;

  /// When the frame was captured.
  final DateTime timestamp;
}

/// Contract for capturing the current device screen.
///
/// Implementations must be fail-closed: if capture is not possible they
/// should throw rather than return a synthetic frame.
abstract class ScreenCaptureService {
  /// Capture the current screen contents.
  ///
  /// Throws on failure; callers wrap in try/catch.
  Future<CapturedFrame> capture();
}
