import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aura_assistant/l10n/app_localizations.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../../core/permissions/permission_service.dart';
import '../../core/theme/app_colors_adaptive.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/voice/voice_service_provider.dart';
import '../../domain/entities/vision/vision_entities.dart';
import '../../services/camera/vision_camera_service.dart';
import '../../services/voice/voice_service.dart' show VoiceState;
import '../../services/vision/vision_service.dart';
import '../providers/app_providers.dart';
import '../widgets/vision_overlay.dart';
import '../widgets/widgets.dart';
import '../../core/providers/phase3_connection_points.dart'
    show voiceStateProvider, voiceTranscriptProvider, aiResponseProvider;

// ─── Vision Analysis Modes ─────────────────────────────────────────

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

/// State of the vision screen camera + analysis.
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

// ─── Vision Screen ──────────────────────────────────────────────────

class VisionScreen extends ConsumerStatefulWidget {
  const VisionScreen({super.key});

  @override
  ConsumerState<VisionScreen> createState() => _VisionScreenState();
}

class _VisionScreenState extends ConsumerState<VisionScreen> {
  // ── Camera State ──
  VisionCameraService? _cameraService;
  CameraController? _cameraController;
  bool _cameraInitialized = false;
  String? _cameraError;
  FlashMode _flashMode = FlashMode.auto;
  double _zoomLevel = 1.0;

  // ── Vision Analysis State ──
  VisionScreenState _screenState = VisionScreenState.initializing;
  VisionMode _currentMode = VisionMode.analyze;
  VisionResult? _lastResult;
  String? _analysisError;
  String? _pendingPrompt; // for findObject / locateTarget

  // ── Voice Integration ──
  bool _voiceActive = false;

  // ── Subscriptions ──
  StreamSubscription<VoiceState>? _voiceStateSub;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _listenToVoiceState();
  }

  @override
  void dispose() {
    _voiceStateSub?.cancel();
    _cameraService?.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────────
  // Camera Initialization
  // ──────────────────────────────────────────────────────────────────

  Future<void> _initCamera() async {
    final permissionService = PermissionService();
    final camResult = await permissionService.requestPermission(
      ph.Permission.camera,
    );

    if (!camResult.isSuccess || !camResult.getOrElse(() => false)) {
      if (mounted) {
        setState(() {
          _screenState = VisionScreenState.error;
          _cameraError = 'permission_denied';
        });
      }
      return;
    }

    _cameraService = ref.read(visionCameraServiceProvider);
    final controller = await _cameraService!.initialize();

    if (controller != null && mounted) {
      setState(() {
        _cameraController = controller;
        _cameraInitialized = true;
        _screenState = VisionScreenState.ready;
      });
    } else if (mounted) {
      setState(() {
        _screenState = VisionScreenState.error;
        _cameraError = 'camera_unavailable';
      });
    }
  }

  // ──────────────────────────────────────────────────────────────────
  // Voice Integration
  // ──────────────────────────────────────────────────────────────────

  void _listenToVoiceState() {
    // When voice state changes, track if voice is active during vision.
    _voiceStateSub?.cancel();
    // We'll use the provider directly in build() to show voice status.
  }

  Future<void> _startVoiceForVision() async {
    if (_voiceActive) return;

    final voiceState = ref.read(voiceStateProvider);
    if (voiceState.isActive) return; // already active from another screen

    final permissionService = PermissionService();
    final micResult = await permissionService.requestPermission(
      ph.Permission.microphone,
    );
    if (!micResult.isSuccess || !micResult.getOrElse(() => false)) return;

    _voiceActive = true;
    final voiceService = ref.read(voiceServiceImplProvider);

    await voiceService.startListening(
      onRecognized: (text) {
        ref.read(voiceTranscriptProvider.notifier).state = text;
        _processVoiceCommand(text);
      },
      locale: 'ckb_IQ',
    );
  }

  Future<void> _stopVoiceForVision() async {
    if (!_voiceActive) return;
    final voiceService = ref.read(voiceServiceImplProvider);
    await voiceService.stopListening();
    _voiceActive = false;
  }

  /// Process a voice command during vision mode.
  void _processVoiceCommand(String text) {
    final lower = text.toLowerCase();

    // Simple keyword-based mode switching.
    if (lower.contains('بگەڕێ') || lower.contains('find') || lower.contains('دۆزینەوە')) {
      _currentMode = VisionMode.findObject;
      _pendingPrompt = text;
      _captureAndAnalyze();
    } else if (lower.contains('بخوێنە') || lower.contains('read') || lower.contains('خوێندنەوە')) {
      _currentMode = VisionMode.readText;
      _captureAndAnalyze();
    } else if (lower.contains('باس بکە') || lower.contains('describe') || lower.contains('دیمەن')) {
      _currentMode = VisionMode.describeScene;
      _captureAndAnalyze();
    } else if (lower.contains('پیشان بدە') || lower.contains('locate') || lower.contains('شوێن')) {
      _currentMode = VisionMode.locateTarget;
      _pendingPrompt = text;
      _captureAndAnalyze();
    } else {
      // Default: general analysis.
      _currentMode = VisionMode.analyze;
      _pendingPrompt = text;
      _captureAndAnalyze();
    }
  }

  // ──────────────────────────────────────────────────────────────────
  // Capture & Analyze
  // ──────────────────────────────────────────────────────────────────

  Future<void> _captureAndAnalyze() async {
    if (_cameraService == null || !_cameraInitialized) return;

    setState(() {
      _screenState = VisionScreenState.analyzing;
      _analysisError = null;
    });

    final base64 = await _cameraService!.capturePhotoAsBase64();
    if (base64 == null) {
      if (mounted) {
        setState(() {
          _screenState = VisionScreenState.error;
          _analysisError = 'capture_failed';
        });
      }
      return;
    }

    final visionService = ref.read(openaiVisionServiceProvider);
    VisionResult result;

    switch (_currentMode) {
      case VisionMode.analyze:
        result = await visionService.analyzeImage(
          imageBase64: base64,
          prompt: _pendingPrompt,
        );
        break;
      case VisionMode.findObject:
        result = await visionService.findObject(
          imageBase64: base64,
          objectName: _pendingPrompt ?? 'object',
        );
        break;
      case VisionMode.readText:
        result = await visionService.readText(
          imageBase64: base64,
          language: 'ku',
        );
        break;
      case VisionMode.describeScene:
        result = await visionService.describeScene(
          imageBase64: base64,
        );
        break;
      case VisionMode.locateTarget:
        result = await visionService.locateTarget(
          imageBase64: base64,
          targetDescription: _pendingPrompt ?? 'target',
          overlayStyle: 'rect',
        );
        break;
    }

    if (mounted) {
      setState(() {
        _lastResult = result;
        _screenState =
            result.isSuccess ? VisionScreenState.result : VisionScreenState.error;
        _analysisError = result.errorMessage;
      });

      // Speak the result description.
      if (result.isSuccess && result.description.isNotEmpty) {
        final voiceService = ref.read(voiceServiceImplProvider);
        await voiceService.speak(result.description);
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────
  // Camera Controls
  // ──────────────────────────────────────────────────────────────────

  Future<void> _switchCamera() async {
    if (_cameraService == null) return;

    setState(() {
      _screenState = VisionScreenState.initializing;
    });

    final newController = await _cameraService!.switchCamera();

    if (newController != null && mounted) {
      setState(() {
        _cameraController = newController;
        _screenState = VisionScreenState.ready;
      });
    } else if (mounted) {
      setState(() {
        _screenState = VisionScreenState.error;
        _cameraError = 'switch_failed';
      });
    }
  }

  Future<void> _toggleFlash() async {
    if (_cameraService == null) return;

    final next = switch (_flashMode) {
      FlashMode.auto => FlashMode.always,
      FlashMode.always => FlashMode.torch,
      FlashMode.torch => FlashMode.off,
      FlashMode.off => FlashMode.auto,
      _ => FlashMode.auto,
    };

    await _cameraService!.setFlashMode(next);
    if (mounted) {
      setState(() => _flashMode = next);
    }
  }

  Future<void> _updateZoom(double delta) async {
    if (_cameraService == null) return;
    final newZoom = (_zoomLevel + delta).clamp(1.0, 5.0);
    await _cameraService!.setZoomLevel(newZoom);
    if (mounted) {
      setState(() => _zoomLevel = newZoom);
    }
  }

  void _resetToReady() {
    if (mounted) {
      setState(() {
        _screenState = VisionScreenState.ready;
        _lastResult = null;
        _analysisError = null;
        _pendingPrompt = null;
      });
    }
  }

  // ──────────────────────────────────────────────────────────────────
  // Build UI
  // ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final voiceState = ref.watch(voiceStateProvider);
    final transcript = ref.watch(voiceTranscriptProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Header Bar ──
            _buildHeader(context, l10n, theme, cs),

            // ── Camera Preview + Overlay ──
            Expanded(
              child: _buildCameraArea(context, cs),
            ),

            // ── Mode Selector ──
            if (_screenState == VisionScreenState.ready)
              _buildModeSelector(context, l10n, cs),

            // ── Result Panel ──
            if (_screenState == VisionScreenState.result && _lastResult != null)
              _buildResultPanel(context, l10n, theme, cs),

            // ── Error Panel ──
            if (_screenState == VisionScreenState.error)
              _buildErrorPanel(context, l10n, cs),

            // ── Bottom Controls ──
            _buildBottomControls(context, l10n, cs, voiceState, transcript),
          ],
        ),
      ),
    );
  }

  // ── Header ──

  Widget _buildHeader(
      BuildContext context, S l10n, ThemeData theme, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            l10n.visionTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          // Voice status indicator during vision
          if (_voiceActive || ref.watch(voiceStateProvider).isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AuraColors.accentOf(context).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.mic_rounded,
                    size: 14,
                    color: AuraColors.accentOf(context),
                  ),
                  SizedBox(width: 4),
                  Text(
                    l10n.voiceListening,
                    style: TextStyle(
                      fontSize: 11,
                      color: AuraColors.accentOf(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Camera Area ──

  Widget _buildCameraArea(BuildContext context, ColorScheme cs) {
    if (_screenState == VisionScreenState.error && !_cameraInitialized) {
      // Camera init error
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_off_outlined, size: 56,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
            SizedBox(height: 12),
            Text(
              _cameraError == 'permission_denied'
                  ? S.of(context).visionCameraPermission
                  : S.of(context).visionCameraError,
              style: TextStyle(color: cs.error, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (!_cameraInitialized || _cameraController == null) {
      // Initializing
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            SizedBox(height: 12),
            Text(
              S.of(context).visionInitializing,
              style: TextStyle(
                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    // Show camera preview with optional overlay.
    final previewSize = _cameraController!.value.previewSize;
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;

    // Calculate scale to cover the available area.
    double scale;
    if (previewSize != null) {
      final scaleW = screenW / previewSize.width;
      final scaleH = screenH / previewSize.height;
      scale = math.max(scaleW, scaleH);
    } else {
      scale = 1.0;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview
        Center(
          child: ClipRect(
            child: Transform.scale(
              scale: scale,
              child: Center(
                child: _cameraController != null
                    ? CameraPreview(_cameraController!)
                    : SizedBox.shrink(),
              ),
            ),
          ),
        ),

        // Vision overlay (targets on top of camera)
        if (_lastResult != null &&
            _lastResult!.isSuccess &&
            _lastResult!.targets.isNotEmpty)
          VisionOverlay(
            result: _lastResult!,
            onTargetTap: (target) {
              // Speak the target description on tap.
              if (target.description != null) {
                final voiceService = ref.read(voiceServiceImplProvider);
                voiceService.speak(target.description!);
              }
            },
          ),

        // Analyzing indicator
        if (_screenState == VisionScreenState.analyzing)
          Container(
            color: Colors.black.withValues(alpha: 0.35),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: AuraColors.accentOf(context),
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    S.of(context).visionAnalyzing,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Zoom indicator
        if (_zoomLevel > 1.05)
          Positioned(
            top: 12,
            right: Directionality.of(context) == TextDirection.rtl ? null : 12,
            left: Directionality.of(context) == TextDirection.rtl ? 12 : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                '${_zoomLevel.toStringAsFixed(1)}x',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Mode Selector ──

  Widget _buildModeSelector(BuildContext context, S l10n, ColorScheme cs) {
    final modes = [
      (VisionMode.analyze, l10n.visionModeAnalyze, Icons.visibility_outlined),
      (VisionMode.findObject, l10n.visionModeFind, Icons.search_outlined),
      (VisionMode.readText, l10n.visionModeRead, Icons.text_fields_outlined),
      (VisionMode.describeScene, l10n.visionModeScene, Icons.landscape_outlined),
      (VisionMode.locateTarget, l10n.visionModeLocate, Icons.gps_fixed_outlined),
    ];

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: modes.length,
        separatorBuilder: (_, __) => SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final (mode, label, icon) = modes[index];
          final isSelected = _currentMode == mode;
          return _ModeChip(
            icon: icon,
            label: label,
            selected: isSelected,
            onTap: () => setState(() => _currentMode = mode),
          );
        },
      ),
    );
  }

  // ── Result Panel ──

  Widget _buildResultPanel(
      BuildContext context, S l10n, ThemeData theme, ColorScheme cs) {
    final result = _lastResult!;

    return Container(
      constraints: const BoxConstraints(maxHeight: 180),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: AuraCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Mode label
              Text(
                _modeLabel(l10n),
                style: TextStyle(
                  fontSize: 11,
                  color: AuraColors.accentOf(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 6),
              // Description
              Text(
                result.description,
                style: TextStyle(fontSize: 13, color: cs.onSurface),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              // OCR text
              if (result.ocrText != null && result.ocrText!.isNotEmpty) ...[
                SizedBox(height: 8),
                Text(
                  l10n.visionOcrResult,
                  style: TextStyle(
                    fontSize: 10,
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  result.ocrText!,
                  style: TextStyle(fontSize: 12, color: cs.onSurface),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              // Target count
              if (result.targets.isNotEmpty) ...[
                SizedBox(height: 8),
                Text(
                  l10n.visionTargetsFound(result.targets.length),
                  style: TextStyle(
                    fontSize: 10,
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Error Panel ──

  Widget _buildErrorPanel(BuildContext context, S l10n, ColorScheme cs) {
    final errorMsg = _analysisError != null
        ? (_analysisError == 'capture_failed'
            ? l10n.visionCaptureError
            : _analysisError!)
        : (_cameraError != null
            ? (_cameraError == 'permission_denied'
                ? l10n.visionCameraPermission
                : l10n.visionCameraError)
            : l10n.error);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: AuraCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        color: cs.errorContainer.withValues(alpha: 0.5),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: cs.error, size: 20),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                errorMsg,
                style: TextStyle(fontSize: 13, color: cs.onErrorContainer),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bottom Controls ──

  Widget _buildBottomControls(
    BuildContext context,
    S l10n,
    ColorScheme cs,
    VoiceState voiceState,
    String transcript,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Switch camera
          _ControlButton(
            icon: Icons.cameraswitch_outlined,
            label: l10n.visionSwitchCamera,
            onTap: _cameraInitialized ? _switchCamera : null,
          ),

          // Flash
          _ControlButton(
            icon: _flashIcon,
            label: l10n.visionFlash,
            onTap: _cameraInitialized ? _toggleFlash : null,
          ),

          // Capture / Re-analyze (big center button)
          _CaptureButton(
            isAnalyzing: _screenState == VisionScreenState.analyzing,
            onTap: _screenState == VisionScreenState.ready ||
                    _screenState == VisionScreenState.result
                ? _captureAndAnalyze
                : null,
          ),

          // Zoom out
          _ControlButton(
            icon: Icons.zoom_out,
            label: l10n.visionZoom,
            onTap: _cameraInitialized ? () => _updateZoom(-0.5) : null,
          ),

          // Zoom in
          _ControlButton(
            icon: Icons.zoom_in,
            label: l10n.visionZoom,
            onTap: _cameraInitialized ? () => _updateZoom(0.5) : null,
          ),

          // Voice toggle
          _ControlButton(
            icon: _voiceActive ? Icons.mic_rounded : Icons.mic_none_outlined,
            label: l10n.visionVoice,
            iconColor: _voiceActive ? AuraColors.accentOf(context) : null,
            onTap: _voiceActive ? _stopVoiceForVision : _startVoiceForVision,
          ),
        ],
      ),
    );
  }

  // ── Helpers ──

  IconData get _flashIcon => switch (_flashMode) {
        FlashMode.auto => Icons.flash_auto,
        FlashMode.always => Icons.flash_on,
        FlashMode.torch => Icons.flashlight_on,
        FlashMode.off => Icons.flash_off,
        _ => Icons.flash_auto,
      };

  String _modeLabel(S l10n) => switch (_currentMode) {
        VisionMode.analyze => l10n.visionModeAnalyze,
        VisionMode.findObject => l10n.visionModeFind,
        VisionMode.readText => l10n.visionModeRead,
        VisionMode.describeScene => l10n.visionModeScene,
        VisionMode.locateTarget => l10n.visionModeLocate,
      };
}

// ─── Mode Chip ──────────────────────────────────────────────────────

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = AuraColors.accentOf(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.18)
              : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: selected
              ? Border.all(color: accent.withValues(alpha: 0.5), width: 1.5)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? accent : cs.onSurfaceVariant,
            ),
            SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? accent : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Control Button ─────────────────────────────────────────────────

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    this.iconColor,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color? iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = onTap != null;

    return SizedBox(
      width: 56,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (iconColor ?? cs.onSurfaceVariant).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(icon, size: 18),
              color: iconColor ?? cs.onSurfaceVariant,
              onPressed: onTap,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
          SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: enabled ? cs.onSurfaceVariant : cs.outline,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── Capture Button (center, larger) ──────────────────────────────────

class _CaptureButton extends StatelessWidget {
  const _CaptureButton({
    required this.isAnalyzing,
    this.onTap,
  });

  final bool isAnalyzing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = AuraColors.accentOf(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isAnalyzing
              ? accent.withValues(alpha: 0.3)
              : accent.withValues(alpha: 0.9),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.7),
            width: 3,
          ),
          boxShadow: isAnalyzing
              ? []
              : [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
        ),
        child: isAnalyzing
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              )
            : Icon(
                Icons.camera_alt_rounded,
                color: Colors.white,
                size: 28,
              ),
      ),
    );
  }
}
