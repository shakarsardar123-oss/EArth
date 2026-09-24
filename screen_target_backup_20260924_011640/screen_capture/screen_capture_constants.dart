/// Platform-channel names and method constants for the AURA
/// screen-capture subsystem.
///
/// These are shared between the Dart [ScreenCaptureMethodChannel]
/// and the Kotlin [ScreenCapturePlugin]. Changing any value here
/// requires the same change on the native side.
library;

/// MethodChannel for control operations.
const String screenCaptureMethodChannelName =
    'com.aura.aura_assistant/screen_capture';

/// EventChannel for frame delivery.
const String screenCaptureEventChannelName =
    'com.aura.aura_assistant/screen_capture_frames';

/// Method names invoked on the platform side.
abstract final class ScreenCaptureMethodNames {
  static const String requestProjection = 'requestProjection';
  static const String startCapture = 'startCapture';
  static const String stopCapture = 'stopCapture';
  static const String captureSingleFrame = 'captureSingleFrame';
  static const String isSupported = 'isSupported';
}
