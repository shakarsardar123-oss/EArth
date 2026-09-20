import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/vision/vision_entities.dart';
import '../../services/camera/vision_camera_service.dart';
import '../../services/vision/vision_service.dart';
import '../../services/vision/vision_service_factory.dart'
import '../../core/errors/result.dart';
    show visionServiceProvider;

// Re-export service providers for convenient access.
export '../../services/camera/vision_camera_service.dart'
    show visionCameraServiceProvider;
export '../../services/vision/vision_service_factory.dart'
    show visionServiceProvider;

// ─── Vision Analysis Modes ──────────────────────────────────────────

/// Different analysis modes the Vision screen can operate in.
enum VisionMode {
  /// General image analysis / description.
  analyze,

  /// Find a specific object.
  findObject,

  /// Read / OCR text from the image.
  readText,

  /// Describe the overall scene.
  describeScene,

  /// Locate a target with visual overlay.
  locateTarget,
}

// ─── Vision Screen State ───────────────────────────────────────────

/// State of the vision screen camera + analysis lifecycle.
enum VisionScreenState {
  /// Camera not yet initialized.
  initializing,

  /// Camera ready, waiting for user action.
  ready,

  /// Photo captured, sending to AI for analysis.
  analyzing,

  /// Analysis complete, showing results.
  result,

  /// An error occurred.
  error,
}

// ─── Vision Screen Notifier ────────────────────────────────────────

/// Manages all vision-screen state: mode, screen state, results,
/// flash, zoom, and pending prompt.
///
/// This notifier is the single source of truth for the VisionScreen
/// Riverpod state, keeping UI logic clean and testable.
class VisionScreenNotifier extends StateNotifier<VisionScreenState> {
  VisionScreenNotifier(
    this._visionService,
    this._cameraService,
  ) : super(VisionScreenState.initializing);

  final VisionService _visionService;
  final VisionCameraService _cameraService;

  // ── Mutable internal state ──

  VisionMode _mode = VisionMode.analyze;
  VisionResult? _lastResult;
  String? _analysisError;
  String? _pendingPrompt;
  FlashMode _flashMode = FlashMode.auto;
  double _zoomLevel = 1.0;
  bool _voiceActive = false;

  // ── Getters ──

  /// Current vision analysis mode.
  VisionMode get mode => _mode;

  /// Last analysis result.
  VisionResult? get lastResult => _lastResult;

  /// Error message from the last failed analysis.
  String? get analysisError => _analysisError;

  /// Pending prompt for find/locate modes.
  String? get pendingPrompt => _pendingPrompt;

  /// Current flash mode.
  FlashMode get flashMode => _flashMode;

  /// Current zoom level (1.0–5.0).
  double get zoomLevel => _zoomLevel;

  /// Whether voice input is currently active.
  bool get voiceActive => _voiceActive;

  // ── Mode ──

  /// Change the current analysis mode.
  void setMode(VisionMode mode) {
    _mode = mode;
  }

  /// Set the pending prompt text (used for find/locate modes).
  void setPendingPrompt(String? prompt) {
    _pendingPrompt = prompt;
  }

  // ── Camera controls ──

  /// Mark the camera as initialized / ready.
  void markReady() {
    state = VisionScreenState.ready;
  }

  /// Mark an error state with a message.
  void markError(String error) {
    _analysisError = error;
    state = VisionScreenState.error;
  }

  /// Cycle through flash modes: auto → always → torch → off → auto.
  Future<void> cycleFlash() async {
    final next = switch (_flashMode) {
      FlashMode.auto => FlashMode.always,
      FlashMode.always => FlashMode.torch,
      FlashMode.torch => FlashMode.off,
      FlashMode.off => FlashMode.auto,
    };
    await _cameraService.setFlashMode(next);
    _flashMode = next;
  }

  /// Update zoom level by [delta].
  Future<void> updateZoom(double delta) async {
    final newZoom = (_zoomLevel + delta).clamp(1.0, 5.0);
    await _cameraService.setZoomLevel(newZoom);
    _zoomLevel = newZoom;
  }

  /// Switch to the other camera (front ↔ back).
  Future<void> switchCamera() async {
    state = VisionScreenState.initializing;
    final controller = await _cameraService.switchCamera();
    if (controller != null) {
      state = VisionScreenState.ready;
    } else {
      _analysisError = 'switch_failed';
      state = VisionScreenState.error;
    }
  }

  // ── Capture & Analyze ──

  /// Capture a photo and run AI analysis based on the current mode.
  Future<void> captureAndAnalyze() async {
    state = VisionScreenState.analyzing;
    _analysisError = null;

    final base64 = await _cameraService.capturePhotoAsBase64();
    if (base64 == null) {
      _analysisError = 'capture_failed';
      state = VisionScreenState.error;
      return;
    }

    VisionResult result;

    switch (_mode) {
      case VisionMode.analyze:
        result = await _visionService.analyzeImage(
          imageBase64: base64,
          prompt: _pendingPrompt,
        );
        break;
      case VisionMode.findObject:
        result = await _visionService.findObject(
          imageBase64: base64,
          objectName: _pendingPrompt ?? 'object',
        );
        break;
      case VisionMode.readText:
        result = await _visionService.readText(
          imageBase64: base64,
          language: 'ku',
        );
        break;
      case VisionMode.describeScene:
        result = await _visionService.describeScene(
          imageBase64: base64,
        );
        break;
      case VisionMode.locateTarget:
        result = await _visionService.locateTarget(
          imageBase64: base64,
          targetDescription: _pendingPrompt ?? 'target',
          overlayStyle: 'rect',
        );
        break;
    }

    _lastResult = result;
    _analysisError = result.errorMessage;
    state = result.isSuccess ? VisionScreenState.result : VisionScreenState.error;
  }

  // ── Voice ──

  /// Mark voice as active/inactive.
  void setVoiceActive(bool active) {
    _voiceActive = active;
  }

  // ── Reset ──

  /// Reset back to ready state, clearing results.
  void resetToReady() {
    state = VisionScreenState.ready;
    _lastResult = null;
    _analysisError = null;
    _pendingPrompt = null;
  }

  /// Process a voice command string for mode switching.
  void processVoiceCommand(String text) {
    final lower = text.toLowerCase();

    if (lower.contains('بگەڕێ') ||
        lower.contains('find') ||
        lower.contains('دۆزینەوە')) {
      _mode = VisionMode.findObject;
      _pendingPrompt = text;
    } else if (lower.contains('بخوێنە') ||
        lower.contains('read') ||
        lower.contains('خوێندنەوە')) {
      _mode = VisionMode.readText;
    } else if (lower.contains('باس بکە') ||
        lower.contains('describe') ||
        lower.contains('دیمەن')) {
      _mode = VisionMode.describeScene;
    } else if (lower.contains('پیشان بدە') ||
        lower.contains('locate') ||
        lower.contains('شوێن')) {
      _mode = VisionMode.locateTarget;
      _pendingPrompt = text;
    } else {
      _mode = VisionMode.analyze;
      _pendingPrompt = text;
    }
  }

  @override
  void dispose() {
    _visionService.dispose();
    _cameraService.dispose();
    super.dispose();
  }
}

// ─── Provider Definitions ─────────────────────────────────────────

/// Provider for the [VisionScreenNotifier].
///
/// This is the main provider for vision screen state management.
/// The notifier manages mode, screen state, results, and camera controls.
final visionScreenProvider =
    StateNotifierProvider<VisionScreenNotifier, VisionScreenState>((ref) {
  final visionService = ref.watch(visionServiceProvider);
  final cameraService = ref.watch(visionCameraServiceProvider);
  return VisionScreenNotifier(visionService, cameraService);
});

/// Provider for the current vision mode (read from notifier).
final visionModeProvider = Provider<VisionMode>((ref) {
  final notifier = ref.watch(visionScreenProvider.notifier);
  return notifier.mode;
});

/// Provider for the last vision result (read from notifier).
final visionResultProvider = Provider<VisionResult?>((ref) {
  final notifier = ref.watch(visionScreenProvider.notifier);
  return notifier.lastResult;
});

/// Provider for the current flash mode (read from notifier).
final visionFlashModeProvider = Provider<FlashMode>((ref) {
  final notifier = ref.watch(visionScreenProvider.notifier);
  return notifier.flashMode;
});

/// Provider for the current zoom level (read from notifier).
final visionZoomProvider = Provider<double>((ref) {
  final notifier = ref.watch(visionScreenProvider.notifier);
  return notifier.zoomLevel;
});

/// Provider for whether voice is active during vision (read from notifier).
final visionVoiceActiveProvider = Provider<bool>((ref) {
  final notifier = ref.watch(visionScreenProvider.notifier);
  return notifier.voiceActive;
});
