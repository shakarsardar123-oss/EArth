import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Provider for WakeCameraService.
final wakeCameraProvider = Provider<WakeCameraService>((ref) {
  return WakeCameraService();
});

/// Privacy-first camera service for wake verification face detection.
///
/// - Camera frames are processed in-memory ONLY, never saved to disk.
/// - Uses Google ML Kit Face Detection (on-device, no network).
/// - Automatically disposes camera when no longer needed.
class WakeCameraService {
  CameraController? _controller;
  FaceDetector? _faceDetector;
  bool _isDetecting = false;
  StreamController<FaceDetectionResult>? _resultController;

  /// Stream of face detection results.
  Stream<FaceDetectionResult> get results =>
      _resultController?.stream ?? const Stream.empty();

  /// Whether the camera is currently active and detecting.
  bool get isDetecting => _isDetecting;

  /// Initialize camera and start face detection.
  /// Returns the CameraController for preview widget.
  Future<CameraController?> startFaceDetection({
    ResolutionPreset resolution = ResolutionPreset.medium,
    bool useFrontCamera = true,
  }) async {
    // Get available cameras.
    final cameras = await availableCameras();
    if (cameras.isEmpty) return null;

    final camera = useFrontCamera
        ? cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
            orElse: () => cameras.first,
          )
        : cameras.first;

    _controller = CameraController(
      camera,
      resolution,
      enableAudio: false,
    );

    await _controller!.initialize();

    // Initialize ML Kit face detector with performance options.
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: false,
        enableLandmarks: false,
        enableContours: false,
        enableTracking: true,
        minFaceSize: 0.15,
        performanceMode: FaceDetectorMode.fast,
      ),
    );

    _resultController = StreamController<FaceDetectionResult>.broadcast();
    _isDetecting = true;

    // Start image stream for real-time face detection.
    await _controller!.startImageStream(_processImageStream);

    return _controller!;
  }

  /// Stop face detection and release all resources.
  Future<void> stopFaceDetection() async {
    _isDetecting = false;

    try {
      await _controller?.stopImageStream();
    } catch (_) {}

    try {
      await _controller?.dispose();
    } catch (_) {}

    await _faceDetector?.close();

    _resultController?.close();

    _controller = null;
    _faceDetector = null;
    _resultController = null;
  }

  /// Process a single camera image for face detection (one-shot).
  Future<FaceDetectionResult> detectFromImage(File imageFile) async {
    final detector = FaceDetector(
      options: FaceDetectorOptions(
        enableTracking: true,
        minFaceSize: 0.15,
        performanceMode: FaceDetectorMode.fast,
      ),
    );

    try {
      final inputImage = InputImage.fromFile(imageFile);
      final faces = await detector.processImage(inputImage);

      if (faces.isNotEmpty) {
        return FaceDetectionResult(
          faceDetected: true,
          confidence: 0.9,
          faceCount: faces.length,
          trackingId: faces.first.trackingId,
        );
      }

      return const FaceDetectionResult(faceDetected: false, faceCount: 0);
    } catch (e) {
      return FaceDetectionResult(
        faceDetected: false,
        faceCount: 0,
        error: e.toString(),
      );
    } finally {
      await detector.close();
    }
  }

  // ── Private helpers ──────────────────────────────────────────

  /// Process each frame from camera image stream.
  void _processImageStream(CameraImage image) async {
    if (!_isDetecting) return;

    // Prevent processing overlap.
    if (_resultController?.isClosed ?? true) return;

    try {
      // Convert CameraImage to InputImage for ML Kit.
      // Use InputImageMetadata (google_mlkit_commons 0.8.x API).
      // Compute a single bytesPerRow from the first plane.
      final firstBytesPerRow = image.planes.isNotEmpty
          ? image.planes.first.bytesPerRow
          : image.width;
      final inputImage = InputImage.fromBytes(
        bytes: _concatPlanes(image),
        metadata: InputImageMetadata(
          size: ui.Size(image.width.toDouble(), image.height.toDouble()),
          rotation: InputImageRotation.rotation0deg,
          format: _getImageFormat(image),
          bytesPerRow: firstBytesPerRow,
        ),
      );

      final faces = await _faceDetector?.processImage(inputImage) ?? [];

      final result = faces.isNotEmpty
          ? FaceDetectionResult(
              faceDetected: true,
              confidence: 0.85,
              faceCount: faces.length,
              trackingId: faces.first.trackingId,
            )
          : const FaceDetectionResult(faceDetected: false, faceCount: 0);

      _resultController?.add(result);
    } catch (e) {
      _resultController?.add(
        FaceDetectionResult(
          faceDetected: false,
          faceCount: 0,
          error: e.toString(),
        ),
      );
    }
  }

  /// Concatenate image plane bytes for ML Kit processing.
  Uint8List _concatPlanes(CameraImage image) {
    final allBytes = <int>[];
    for (final plane in image.planes) {
      allBytes.addAll(plane.bytes);
    }
    return Uint8List.fromList(allBytes);
  }

  InputImageFormat _getImageFormat(CameraImage image) {
    // NV21 / YV12 are common on Android.
    switch (image.format.group) {
      case ImageFormatGroup.yuv420:
        return InputImageFormat.nv21;
      case ImageFormatGroup.bgra8888:
        return InputImageFormat.bgra8888;
      default:
        return InputImageFormat.nv21;
    }
  }
}

/// Result of a face detection attempt.
class FaceDetectionResult {
  const FaceDetectionResult({
    required this.faceDetected,
    required this.faceCount,
    this.confidence = 0.0,
    this.trackingId,
    this.error,
  });

  /// Whether at least one face was detected.
  final bool faceDetected;

  /// Number of faces detected.
  final int faceCount;

  /// Detection confidence (0.0 – 1.0).
  final double confidence;

  /// ML Kit tracking ID for the primary face (stable across frames).
  final int? trackingId;

  /// Error message if detection failed.
  final String? error;

  /// Whether detection encountered an error.
  bool get hasError => error != null;
}

