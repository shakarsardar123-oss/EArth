import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart' as cam;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for VisionCameraService.
final visionCameraServiceProvider = Provider<VisionCameraService>((ref) {
  return VisionCameraService();
});

/// General-purpose camera service for the Live Vision feature.
///
/// Provides camera preview, photo capture (returning base64 for AI analysis),
/// lens switching, and lifecycle management.
/// Separate from [WakeCameraService] which is face-detection only.
class VisionCameraService {
  cam.CameraController? _controller;
  bool _isInitialized = false;
  cam.CameraDescription? _currentCamera;
  List<cam.CameraDescription> _cameras = [];
  cam.ResolutionPreset _resolutionPreset = cam.ResolutionPreset.high;

  /// Whether the camera controller has been initialized.
  bool get isInitialized => _isInitialized;

  /// The current camera controller (for preview texture).
  cam.CameraController? get controller => _controller;

  /// Available camera descriptions.
  List<cam.CameraDescription> get availableCameras =>
      List.unmodifiable(_cameras);

  /// Current camera description.
  cam.CameraDescription? get currentCamera => _currentCamera;

  /// Current lens direction.
  cam.CameraLensDirection get currentLensDirection =>
      _currentCamera?.lensDirection ?? cam.CameraLensDirection.back;

  /// Initialize the camera with the given lens direction.
  ///
  /// Returns the [cam.CameraController] for building the preview widget.
  Future<cam.CameraController?> initialize({
    cam.CameraLensDirection lensDirection = cam.CameraLensDirection.back,
    cam.ResolutionPreset resolution = cam.ResolutionPreset.high,
  }) async {
    if (_isInitialized) {
      return _controller;
    }

    _resolutionPreset = resolution;

    try {
      _cameras = await cam.availableCameras();
      if (_cameras.isEmpty) return null;

      _currentCamera = _cameras.firstWhere(
        (c) => c.lensDirection == lensDirection,
        orElse: () => _cameras.first,
      );

      _controller = cam.CameraController(
        _currentCamera!,
        resolution,
        enableAudio: false,
      );

      await _controller!.initialize();
      _isInitialized = true;

      return _controller;
    } catch (e) {
      _isInitialized = false;
      return null;
    }
  }

  /// Capture a photo and return it as a base64-encoded JPEG string
  /// (no data: prefix), suitable for the gpt-4o vision API.
  Future<String?> capturePhotoAsBase64() async {
    if (!_isInitialized || _controller == null) return null;

    try {
      final xFile = await _controller!.takePicture();
      final bytes = await File(xFile.path).readAsBytes();
      return base64Encode(bytes);
    } catch (e) {
      return null;
    }
  }

  /// Capture a photo and return the file path.
  Future<String?> capturePhoto() async {
    if (!_isInitialized || _controller == null) return null;

    try {
      final xFile = await _controller!.takePicture();
      return xFile.path;
    } catch (e) {
      return null;
    }
  }

  /// Switch between front and back cameras.
  ///
  /// Returns the new [cam.CameraController] after switching,
  /// or null if switching failed.
  Future<cam.CameraController?> switchCamera() async {
    if (!_isInitialized) return null;

    final newDirection = _currentCamera?.lensDirection ==
            cam.CameraLensDirection.back
        ? cam.CameraLensDirection.front
        : cam.CameraLensDirection.back;

    final newCamera = _cameras.firstWhere(
      (c) => c.lensDirection == newDirection,
      orElse: () => _currentCamera!,
    );

    if (newCamera == _currentCamera) return _controller;

    // Dispose old controller.
    await _controller?.dispose();
    _isInitialized = false;

    // Initialize new controller.
    _currentCamera = newCamera;
    _controller = cam.CameraController(
      newCamera,
      _resolutionPreset,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      _isInitialized = true;
      return _controller;
    } catch (e) {
      _isInitialized = false;
      return null;
    }
  }

  /// Toggle the camera flash mode.
  Future<void> setFlashMode(cam.FlashMode mode) async {
    if (!_isInitialized || _controller == null) return;
    try {
      await _controller!.setFlashMode(mode);
    } catch (_) {}
  }

  /// Set zoom level (1.0 = no zoom).
  Future<void> setZoomLevel(double zoom) async {
    if (!_isInitialized || _controller == null) return;
    try {
      final minZoom = await _controller!.getMinZoomLevel();
      final maxZoom = await _controller!.getMaxZoomLevel();
      final clamped = zoom.clamp(minZoom, maxZoom);
      await _controller!.setZoomLevel(clamped);
    } catch (_) {}
  }

  /// Pause the camera preview.
  Future<void> pausePreview() async {
    if (!_isInitialized || _controller == null) return;
    try {
      await _controller!.pausePreview();
    } catch (_) {}
  }

  /// Resume the camera preview.
  Future<void> resumePreview() async {
    if (!_isInitialized || _controller == null) return;
    try {
      await _controller!.resumePreview();
    } catch (_) {}
  }

  /// Dispose the camera and release all resources.
  Future<void> dispose() async {
    _isInitialized = false;
    try {
      await _controller?.dispose();
    } catch (_) {}
    _controller = null;
    _currentCamera = null;
  }
}
