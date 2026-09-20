import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/camera/wake_camera_service.dart';

/// ConsumerStatefulWidget that shows a live camera preview from WakeCameraService.
///
/// When the camera is not yet initialized, a placeholder icon is shown.
/// When initialized, the CameraController preview is displayed.
class CameraPreviewWidget extends ConsumerStatefulWidget {
  const CameraPreviewWidget({super.key});

  @override
  ConsumerState<CameraPreviewWidget> createState() =>
      _CameraPreviewWidgetState();
}

class _CameraPreviewWidgetState extends ConsumerState<CameraPreviewWidget> {
  CameraController? _controller;
  bool _initialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameraService = ref.read(wakeCameraProvider);
    try {
      final ctrl = await cameraService.startFaceDetection();
      if (ctrl != null && mounted) {
        setState(() {
          _controller = ctrl;
          _initialized = true;
        });
      } else if (mounted) {
        setState(() {
          _error = 'No camera available';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    final cameraService = ref.read(wakeCameraProvider);
    cameraService.stopFaceDetection();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_off, size: 48,
                color: cs.onSurfaceVariant.withOpacity(0.5)),
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: cs.error, fontSize: 12)),
          ],
        ),
      );
    }

    if (!_initialized) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(height: 8),
            Text('Initializing camera...',
                style: TextStyle(
                    color: cs.onSurfaceVariant.withOpacity(0.7),
                    fontSize: 12)),
          ],
        ),
      );
    }

    // Show live camera preview.
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _controller!.value.previewSize?.width ?? 320,
          height: _controller!.value.previewSize?.height ?? 240,
          child: CameraPreview(_controller!),
        ),
      ),
    );
  }
}
