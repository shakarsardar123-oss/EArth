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
///
/// Every operation (start, stop, switch, flash) runs one after another in a
/// queue, so pressing the buttons quickly can never open or close the camera
/// twice at the same time.
class LiveCamera {
  final ValueNotifier<bool> active = ValueNotifier<bool>(false);

  /// Flash on. Back camera: the real torch. Front camera: the UI draws a
  /// bright screen light instead (phones have no front torch).
  final ValueNotifier<bool> torchOn = ValueNotifier<bool>(false);

  /// True while the front camera is open.
  final ValueNotifier<bool> isFront = ValueNotifier<bool>(false);

  /// Photos are only taken while this is true (the assistant is listening).
  bool capturing = true;

  CameraController? _ctl;
  List<CameraDescription> _cams = const <CameraDescription>[];
  int _idx = 0;
  Timer? _timer;
  bool _busy = false;
  Future<void> _queue = Future<void>.value();
  int _epoch = 0;

  Future<void> _run(Future<void> Function() job) {
    final Future<void> next = _queue.then((_) => job()).catchError((Object _) {});
    _queue = next;
    return next;
  }

  Future<void> start() => _run(_start);

  Future<void> stop() {
    _epoch++; // an unfinished start / switch notices this and gives up
    return _run(_stop);
  }

  Future<void> switchCamera() => _run(_switch);

  Future<void> toggleTorch() => _run(_torch);

  Future<void> _start() async {
    if (active.value) return;
    final int ep = _epoch;
    try {
      final PermissionStatus st = await Permission.camera.request();
      if (!st.isGranted || ep != _epoch) return;
      _cams = await availableCameras();
      if (_cams.isEmpty || ep != _epoch) return;
      final int back =
          _cams.indexWhere((CameraDescription c) => c.lensDirection == CameraLensDirection.back);
      _idx = back >= 0 ? back : 0;
      await _open(ep);
    } catch (_) {
      await _stop();
    }
  }

  Future<void> _open(int ep) async {
    final CameraController? old = _ctl;
    _ctl = null;
    active.value = false;
    torchOn.value = false;
    try {
      await old?.dispose();
    } catch (_) {}
    final CameraController c = CameraController(
      _cams[_idx],
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await c.initialize();
      // The default is "auto": in a dark room every still photo (one every 2 s)
      // fired the flash like a camera. The flash only runs when the user asks.
      try {
        await c.setFlashMode(FlashMode.off);
      } catch (_) {}
    } catch (_) {
      try {
        await c.dispose();
      } catch (_) {}
      rethrow;
    }
    if (ep != _epoch) {
      try {
        await c.dispose();
      } catch (_) {}
      return;
    }
    _ctl = c;
    isFront.value = _cams[_idx].lensDirection == CameraLensDirection.front;
    LiveVisionFrame.enabled = true;
    active.value = true;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 2), (Timer _) => _capture());
    unawaited(_capture());
  }

  Future<void> _switch() async {
    if (!active.value || _cams.length < 2) return;
    final int ep = _epoch;
    final CameraLensDirection cur = _cams[_idx].lensDirection;
    int next = _cams.indexWhere((CameraDescription c) =>
        c.lensDirection != cur && c.lensDirection != CameraLensDirection.external);
    if (next < 0) next = (_idx + 1) % _cams.length;
    _idx = next;
    try {
      await _open(ep);
    } catch (_) {
      await _stop();
    }
  }

  Future<void> _torch() async {
    final CameraController? c = _ctl;
    if (c == null || !c.value.isInitialized) return;
    final bool want = !torchOn.value;
    if (isFront.value) {
      torchOn.value = want; // the UI draws the screen light
      return;
    }
    try {
      await c.setFlashMode(want ? FlashMode.torch : FlashMode.off);
      torchOn.value = want;
    } catch (_) {}
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
      // Some phones switch the torch off when a photo is taken: put it back.
      if (torchOn.value && !isFront.value) {
        try {
          await c.setFlashMode(FlashMode.torch);
        } catch (_) {}
      }
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

  Future<void> _stop() async {
    _timer?.cancel();
    _timer = null;
    active.value = false;
    torchOn.value = false;
    LiveVisionFrame.clear();
    final CameraController? c = _ctl;
    _ctl = null;
    try {
      await c?.setFlashMode(FlashMode.off);
    } catch (_) {}
    try {
      await c?.dispose();
    } catch (_) {}
  }
}
