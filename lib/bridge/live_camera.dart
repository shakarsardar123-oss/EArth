import 'dart:async';
import 'dart:io' show File;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/vision/live_vision_frame.dart';

/// Camera for Live Mode: shows a preview and keeps the latest still frame in
/// [LiveVisionFrame] (one photo every 2 s, only while the assistant listens).
class LiveCamera {
  final ValueNotifier<bool> active = ValueNotifier<bool>(false);

  /// Photos are only taken while this is true (the assistant is listening).
  bool capturing = true;

  CameraController? _ctl;
  List<CameraDescription> _cams = const <CameraDescription>[];
  int _idx = 0;
  Timer? _timer;
  bool _busy = false;
  bool _starting = false;

  Future<void> start() async {
    if (active.value || _starting) return;
    _starting = true;
    try {
      final PermissionStatus st = await Permission.camera.request();
      if (!st.isGranted) return;
      _cams = await availableCameras();
      if (_cams.isEmpty) return;
      final int back =
          _cams.indexWhere((CameraDescription c) => c.lensDirection == CameraLensDirection.back);
      _idx = back >= 0 ? back : 0;
      await _open();
    } catch (_) {
      await stop();
    } finally {
      _starting = false;
    }
  }

  Future<void> _open() async {
    final CameraController? old = _ctl;
    _ctl = null;
    active.value = false;
    try {
      await old?.dispose();
    } catch (_) {}
    final CameraController c = CameraController(
      _cams[_idx],
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await c.initialize();
    _ctl = c;
    LiveVisionFrame.enabled = true;
    active.value = true;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 2), (Timer _) => _capture());
    unawaited(_capture());
  }

  Future<void> switchCamera() async {
    if (!active.value || _cams.length < 2) return;
    _idx = (_idx + 1) % _cams.length;
    try {
      await _open();
    } catch (_) {
      await stop();
    }
  }

  Future<void> _capture() async {
    final CameraController? c = _ctl;
    if (c == null || !c.value.isInitialized || _busy || !capturing) return;
    if (c.value.isTakingPicture) return;
    _busy = true;
    try {
      final XFile f = await c.takePicture();
      final Uint8List bytes = await f.readAsBytes();
      LiveVisionFrame.set(bytes);
      try {
        await File(f.path).delete();
      } catch (_) {}
    } catch (_) {
      // ignore: a missed frame is fine
    } finally {
      _busy = false;
    }
  }

  Widget? preview() {
    final CameraController? c = _ctl;
    if (c == null || !c.value.isInitialized) return null;
    final Size? ps = c.value.previewSize;
    if (ps == null) return CameraPreview(c);
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(width: ps.height, height: ps.width, child: CameraPreview(c)),
    );
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    active.value = false;
    LiveVisionFrame.clear();
    final CameraController? c = _ctl;
    _ctl = null;
    try {
      await c?.dispose();
    } catch (_) {}
  }
}
