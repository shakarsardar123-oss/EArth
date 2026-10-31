/// earth_textures.dart
/// AURA — Real Earth texture loader (decode ONCE, cache forever).
///
/// Loads the equirectangular NASA / Visible Earth public-domain textures used
/// by the textured 3D sphere renderer:
///   • earth_surface.jpg  — NASA "Blue Marble" land+ocean shallow topography
///   • earth_clouds.jpg    — NASA combined cloud map
///   • earth_night.jpg     — NASA "Earth at night" city lights (Black Marble)
///
/// All three are public-domain NASA imagery (https://visibleearth.nasa.gov).
///
/// PERFORMANCE CONTRACT:
///   • Each texture is decoded to a [ui.Image] exactly once and cached.
///   • Textures are NEVER decoded or reloaded during animation.
///   • Loading is async and non-blocking; the renderer draws a plain shaded
///     ocean sphere until [surface] is ready, so the UI never stalls or
///     throws while decoding.
library;

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

class EarthTextures {
  EarthTextures._();
  static final EarthTextures instance = EarthTextures._();

  static const String _surfaceAsset =
      'assets/textures/earth/earth_surface.jpg';
  static const String _cloudsAsset = 'assets/textures/earth/earth_clouds.jpg';
  static const String _nightAsset = 'assets/textures/earth/earth_night.jpg';

  ui.Image? _surface;
  ui.Image? _clouds;
  ui.Image? _night;

  Future<void>? _loading;
  bool _failed = false;

  /// Decoded surface texture, or null until loaded.
  ui.Image? get surface => _surface;
  ui.Image? get clouds => _clouds;
  ui.Image? get night => _night;

  /// True once the surface texture (the minimum needed to look like Earth)
  /// is decoded and cached.
  bool get isReady => _surface != null;

  /// True if loading was attempted and the surface texture failed to decode
  /// (missing asset / unsupported format). The renderer then keeps its
  /// shaded-ocean fallback rather than throwing.
  bool get hasFailed => _failed;

  /// Idempotent. Kicks off (and awaits) a single decode of all textures.
  /// Safe to call from many places / frames — the work runs at most once.
  Future<void> ensureLoaded() {
    if (_surface != null) return Future<void>.value();
    return _loading ??= _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<ui.Image?>(<Future<ui.Image?>>[
        _decodeAsset(_surfaceAsset),
        _decodeAsset(_cloudsAsset),
        _decodeAsset(_nightAsset),
      ]);
      _surface = results[0];
      _clouds = results[1];
      _night = results[2];
      _failed = _surface == null;
    } catch (e) {
      _failed = true;
      if (kDebugMode) {
        debugPrint('EarthTextures: failed to load Earth textures: $e');
      }
    }
  }

  Future<ui.Image?> _decodeAsset(String key) async {
    try {
      final ByteData data = await rootBundle.load(key);
      final Uint8List bytes = data.buffer.asUint8List();
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frame = await codec.getNextFrame();
      return frame.image;
    } catch (e) {
      if (kDebugMode) debugPrint('EarthTextures: could not decode $key: $e');
      return null;
    }
  }

  /// TEST/lifecycle helper — dispose cached images and reset state.
  @visibleForTesting
  void resetForTest() {
    _surface?.dispose();
    _clouds?.dispose();
    _night?.dispose();
    _surface = null;
    _clouds = null;
    _night = null;
    _loading = null;
    _failed = false;
  }
}
