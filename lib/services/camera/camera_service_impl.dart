/// camera_service_impl.dart
/// AURA Assistant — Concrete CameraService implementation
///
/// Implements the abstract [CameraService] interface using
/// the `image_picker` package for gallery selection and camera capture.
///
/// This is the simple capture/gallery service used by tools.
/// The live-vision camera (VisionCameraService) is a separate
/// standalone class for camera preview and does NOT implement CameraService.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'camera_service.dart';
import '../../presentation/providers/app_providers.dart'
    show flutterSecureStorageProvider;

/// Concrete implementation of [CameraService] using image_picker.
class CameraServiceImpl implements CameraService {
  CameraServiceImpl({ImagePicker? imagePicker})
      : _imagePicker = imagePicker ?? ImagePicker();

  final ImagePicker _imagePicker;

  @override
  Future<bool> isCameraAvailable() async {
    try {
      // image_picker doesn't expose a direct "isAvailable" check,
      // so we return true — the actual call will fail gracefully if no camera.
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> capturePhoto() async {
    try {
      final xFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      return xFile?.path;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> pickImageFromGallery() async {
    try {
      final xFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      return xFile?.path;
    } catch (_) {
      return null;
    }
  }
}

/// Riverpod provider for [CameraServiceImpl].
final cameraServiceImplProvider = Provider<CameraServiceImpl>((ref) {
  return CameraServiceImpl();
});
