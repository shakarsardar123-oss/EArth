import '../../core/phone_agent/phone_control_processor.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'scope.dart';

/// Detects objects in the camera image and shows labels + rough position.
class ObjectTestScreen extends StatefulWidget {
  const ObjectTestScreen({super.key});
  @override
  State<ObjectTestScreen> createState() => _ObjectTestScreenState();
}

class _ObjectTestScreenState extends State<ObjectTestScreen> {
  CameraController? _cam;
  final ObjectDetector _det = ObjectDetector(
    options: ObjectDetectorOptions(
      mode: DetectionMode.stream,
      classifyObjects: true,
      multipleObjects: true,
    ),
  );
  bool _busy = false;
  Size _size = const Size(1, 1);
  String _text = 'ئامادە دەبێت...';
  String _status = '';
  String _target = '';
  @override
  void initState() {
    super.initState();
    _target = PhoneControlProcessor.objectFindTarget;
    _start();
  }
  String _findResult = '';
  String _lastSpoken = '';
  final Set<String> _spokenOnce = <String>{};


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
      await cam.startImageStream(_onImage);
      if (mounted) setState(() => _status = 'بەردەوامە، شتێک بخە بەردەم کامێرا');
    } catch (e) {
      if (mounted) setState(() => _status = 'هەڵە: $e');
    }
  }

  String _where(Rect b) {
    final cx = b.center.dx / _size.width;
    final cy = b.center.dy / _size.height;
    final h = cx < 0.33 ? 'چەپ' : (cx > 0.66 ? 'ڕاست' : 'ناوەڕاست');
    final v = cy < 0.33 ? 'سەرەوە' : (cy > 0.66 ? 'خوارەوە' : 'ناوەند');
    return '$v، $h';
  }

  Future<void> _onImage(CameraImage img) async {
    if (_busy) return;
    _busy = true;
    try {
      final input = _toInput(img);
      if (input == null) return;
      _size = Size(img.width.toDouble(), img.height.toDouble());
      final objs = await _det.processImage(input);
      final lines = <String>[];
      for (final o in objs) {
        if (o.labels.isEmpty) {
          lines.add('شت (ناسراو) · ${_where(o.boundingBox)}');
          continue;
        }
        final l = o.labels.first;
        lines.add('${l.text} ${(l.confidence * 100).round()}% · ${_where(o.boundingBox)}');
      }
      if (_target.isNotEmpty) {
        final t = _target.toLowerCase();
        String? hit;
        for (final o in objs) {
          final names = o.labels.map((l) => l.text.toLowerCase()).join(' ');
          if (names.contains(t)) {
            hit = _where(o.boundingBox);
            break;
          }
        }
        if (hit != null && _findResult != 'found') {
          _findResult = 'found';
          try { await _speak('دۆزیمەوە، لە $hit'); } catch (_) {}
        } else if (hit == null) {
          _findResult = '';
        }
      }
      if (mounted) {
        setState(() => _text = lines.isEmpty ? 'هیچ شتێک نەدۆزرایەوە' : lines.join('\n'));
      }
      if (objs.isNotEmpty && objs.first.labels.isNotEmpty) {
        final name = objs.first.labels.first.text;
        if (!_spokenOnce.contains(name)) {
          _spokenOnce.add(name);
          _lastSpoken = name;
          try { await _speak('لێرەوە دەبینم: $name'); } catch (_) {}
        }
      }
    } catch (e) {
      if (mounted) setState(() => _status = 'هەڵەی پرۆسێس: $e');
    } finally {
      _busy = false;
    }
  }

  InputImage? _toInput(CameraImage img) {
    final cam = _cam;
    if (cam == null) return null;
    final rotation = InputImageRotationValue.fromRawValue(cam.description.sensorOrientation);
    if (rotation == null) return null;
    final total = img.planes.fold<int>(0, (n, pl) => n + pl.bytes.length);
    final all = Uint8List(total);
    var off = 0;
    for (final plane in img.planes) {
      all.setRange(off, off + plane.bytes.length, plane.bytes);
      off += plane.bytes.length;
    }
    return InputImage.fromBytes(
      bytes: all,
      metadata: InputImageMetadata(
        size: Size(img.width.toDouble(), img.height.toDouble()),
        rotation: rotation,
        format: InputImageFormatValue.fromRawValue(img.format.raw) ?? InputImageFormat.nv21,
        bytesPerRow: img.planes.first.bytesPerRow,
      ),
    );
  }

  Future<void> _speak(String text) async {
    // Wired to the app's voice service through a provider in the screen's parent.
    await UiScope.of(context).backend.speak(text);
  }

  bool _askingVision = false;

  Future<void> _askVision(String what) async {
    final cam = _cam;
    if (cam == null || _askingVision) return;
    _askingVision = true;
    try {
      final img = await cam.takePicture();
      final bytes = await img.readAsBytes();
      final r = await UiScope.of(context).backend.speak('تاقیکردنەوە: $what');
      if (mounted) setState(() => _status = 'وێنە گیرا (${bytes.length} بایت)');
      // Gemini call goes through the app's provider in the next step.
    } catch (e) {
      if (mounted) setState(() => _status = 'هەڵە: $e');
    } finally {
      _askingVision = false;
    }
  }

  @override
  void dispose() {
    _cam?.dispose();
    _det.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cam = _cam;
    return Scaffold(
      appBar: AppBar(title: const Text('تاقیکردنەوەی ئامێر و شت')),
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
              '$_text\n$_status',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
