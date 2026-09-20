/// Abstraction for camera capture and image selection.
///
/// Phase 2+ will implement camera and gallery access.
/// Phase 1 provides the contract only.
abstract class CameraService {
  /// Whether a camera is available on this device.
  Future<bool> isCameraAvailable();

  /// Captures a photo from the device camera.
  ///
  /// Returns the file path of the captured image, or `null` if
  /// the user cancels.
  Future<String?> capturePhoto();

  /// Opens the device gallery for image selection.
  ///
  /// Returns the file path of the selected image, or `null` if
  /// the user cancels.
  Future<String?> pickImageFromGallery();
}
