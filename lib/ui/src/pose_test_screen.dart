import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Tests pose detection on this device: shows FPS and how many landmarks are seen.
class PoseTestScreen extends StatefulWidget {
  const PoseTestScreen({super.key});
  @override
  State<PoseTestScreen> createState() => _PoseTestScreenState();
}

class _PoseTestScreenState extends State<PoseTestScreen> {
  CameraController? _cam;
  final PoseDetector _detector = PoseDetector(
    options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
  );
  bool _busy = false;
  int _frames = 0;
  double _fps = 0;
  int _landmarks = 0;
  String _status = 'ئامادە دەبێت...';
  Timer? _fpsTimer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final cams = await availableCameras();
      final back = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );
      final cam = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );
      await cam.initialize();
      _cam = cam;
      _fpsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          _fps = _frames.toDouble();
          _frames = 0;
        });
      });
      await cam.startImageStream(_onImage);
      if (mounted) setState(() => _status = 'بەردەوامە، لەشت لەبەردەم کامێرا بێت');
    } catch (e) {
      if (mounted) setState(() => _status = 'هەڵە: $e');
    }
  }

  Future<void> _onImage(CameraImage img) async {
    if (_busy) return;
    _busy = true;
    try {
      final input = _toInput(img);
      if (input == null) return;
      final poses = await _detector.processImage(input);
      _frames++;
      if (mounted) {
        setState(() => _landmarks = poses.isEmpty ? 0 : poses.first.landmarks.length);
      }
    } catch (_) {
    } finally {
      _busy = false;
    }
  }

  InputImage? _toInput(CameraImage img) {
    final cam = _cam;
    if (cam == null) return null;
    final rotation = InputImageRotationValue.fromRawValue(cam.description.sensorOrientation);
    if (rotation == null) return null;
    final bytes = WriteBuffer();
    for (final plane in img.planes) {
      bytes.putUint8List(plane.bytes);
    }
    return InputImage.fromBytes(
      bytes: bytes.done().buffer.asUint8List(),
      metadata: InputImageMetadata(
        size: Size(img.width.toDouble(), img.height.toDouble()),
        rotation: rotation,
        format: InputImageFormatValue.fromRawValue(img.format.raw) ?? InputImageFormat.nv21,
        bytesPerRow: img.planes.first.bytesPerRow,
      ),
    );
  }

  @override
  void dispose() {
    _fpsTimer?.cancel();
    _cam?.dispose();
    _detector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cam = _cam;
    return Scaffold(
      appBar: AppBar(title: const Text('تاقیکردنەوەی پۆز')),
      body: Column(
        children: [
          Expanded(
            child: cam == null || !cam.value.isInitialized
                ? Center(child: Text(_status))
                : CameraPreview(cam),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'FPS: ${_fps.toStringAsFixed(0)}   خاڵەکان: $_landmarks\n$_status',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
