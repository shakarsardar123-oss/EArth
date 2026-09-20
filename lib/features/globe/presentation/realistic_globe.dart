/// realistic_globe.dart
/// AURA — Photorealistic, texture-mapped 3D Earth (GPU-rasterized).
///
/// RENDERER: a real texture-mapped UV sphere drawn with `Canvas.drawVertices`
/// + an `ImageShader` of NASA public-domain equirectangular imagery. Triangle
/// rasterization + texture sampling run on the GPU (Impeller/Skia) with NO
/// native plugin and NO extra pub dependency — only `dart:ui`. The CPU only
/// transforms a few thousand cached vertices per frame (see [SphereMesh]).
///
/// LAYERS (back → front): lit atmosphere → day surface (Blue Marble, Lambert
/// shaded) → night city-lights on the dark side → subtle cloud layer → thin
/// atmospheric rim → AURA highlight (marker/ring/connector/label).
///
/// PRESERVED PERFORMANCE ARCHITECTURE (from the prior optimization pass):
///   • NO per-frame setState — the ticker mutates a [_GlobeFrame] holder and
///     the painter repaints via a merged [Listenable] (ticker + controller).
///   • RepaintBoundary isolates the globe layer.
///   • Static geometry + textures created ONCE and cached; reused typed-array
///     buffers; cached Paints/shaders; cached label TextPainter.
///   • Elapsed-dt rotation (refresh-rate independent, 60/90/120Hz safe).
///   • Lifecycle-safe ticker (pause/resume/dispose).
///   • DEV-ONLY FPS/frame-time/jank overlay (debug-gated, default off).
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kDebugMode, ValueListenable;
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../application/globe_controller.dart';
import '../domain/globe_models.dart';
import 'earth_textures.dart';
import 'sphere_geometry.dart';

/// Shared static sphere mesh (generated once for the whole app).
final SphereMesh _kSphere = SphereMesh.generate(stacks: 40, slices: 80);

class RealisticGlobe extends StatefulWidget {
  const RealisticGlobe({
    super.key,
    required this.controller,
    this.size = 220,
    this.active = true,
    this.semanticLabel,
    this.debugShowPerfOverlay = false,
  });

  final GlobeController controller;

  /// Diameter in logical pixels at zoom 1.0.
  final double size;

  /// When false, the idle spin pauses (e.g. off-screen) to save battery.
  final bool active;

  final String? semanticLabel;

  /// DEV-ONLY. When true AND running in a debug build, a tiny FPS / frame-time
  /// / jank overlay is drawn on top of the globe. No-op in release builds and
  /// defaults to false, so production UI is never affected.
  final bool debugShowPerfOverlay;

  @override
  State<RealisticGlobe> createState() => _RealisticGlobeState();
}

class _RealisticGlobeState extends State<RealisticGlobe>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;

  // Mutable per-frame view holder. Advanced in _onFrame WITHOUT setState;
  // the painter reads it live and repaints via the [_repaint] Listenable.
  final _GlobeFrame _frame = _GlobeFrame();

  late final Listenable _repaint;

  // Idle spin (Earth turns toward the LEFT) in degrees/sec of center longitude.
  static const double _spinDegPerSec = 6.0;
  // Clouds drift very slightly faster than the surface for subtle life.
  static const double _cloudExtraDegPerSec = 0.8;
  Duration _lastTick = Duration.zero;
  bool _reducedMotion = false;

  // DEV-ONLY perf sampling.
  final ValueNotifier<_PerfSample> _perf =
      ValueNotifier<_PerfSample>(_PerfSample.zero);
  double _perfAccumSec = 0.0;
  int _perfFrames = 0;
  double _perfWorstMs = 0.0;
  int _perfJank = 0;

  bool get _perfEnabled => widget.debugShowPerfOverlay && kDebugMode;

  @override
  void initState() {
    super.initState();
    // Begin decoding the Earth textures once; the painter shows a shaded
    // ocean sphere until they are ready and the repeating ticker picks them
    // up on the next frame (no setState / rebuild needed).
    EarthTextures.instance.ensureLoaded();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    );
    _repaint = Listenable.merge(<Listenable>[_ticker, widget.controller]);
    _ticker.addListener(_onFrame);
    if (widget.active) _ticker.repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  @override
  void didUpdateWidget(covariant RealisticGlobe oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_ticker.isAnimating) {
      _ticker.repeat();
    } else if (!widget.active && _ticker.isAnimating) {
      _ticker.stop();
    }
  }

  void _onFrame() {
    final now = _ticker.lastElapsedDuration ?? Duration.zero;
    double dt = (now - _lastTick).inMicroseconds / 1e6;
    _lastTick = now;
    if (dt <= 0 || dt > 0.25) dt = 1 / 60; // guard against jumps/wrap.

    final c = widget.controller;
    final tgtLon = c.targetLongitude;
    final tgtLat = c.targetLatitude;

    if (tgtLon == null && tgtLat == null) {
      // Idle: continuous LEFT-only rotation (no random motion).
      if (!_reducedMotion) {
        _frame.lon0 = _wrapLon(_frame.lon0 + _spinDegPerSec * dt);
      }
      _frame.lat0 = _lerp(_frame.lat0, 0.0, dt * 2.0);
    } else {
      // Cinematic flight: ease toward the requested center along the SHORTEST
      // angular path (no unrealistic full-Earth spin), decelerating near the
      // target. Exponential smoothing gives smooth accel + settle, no overshoot.
      if (tgtLon != null) {
        _frame.lon0 = _lerpAngle(_frame.lon0, tgtLon, dt * 2.6);
      }
      if (tgtLat != null) _frame.lat0 = _lerp(_frame.lat0, tgtLat, dt * 2.6);
    }
    _frame.zoom = _lerp(_frame.zoom, c.targetZoom, dt * 2.6);
    _frame.pan = _lerp(_frame.pan, c.panRight, dt * 4.0);
    if (!_reducedMotion) {
      _frame.cloudLon = _wrapLon(_frame.cloudLon + _cloudExtraDegPerSec * dt);
    }

    if (_perfEnabled) _samplePerf(dt);
  }

  void _samplePerf(double dt) {
    final ms = dt * 1000.0;
    _perfFrames++;
    _perfAccumSec += dt;
    if (ms > _perfWorstMs) _perfWorstMs = ms;
    if (ms > 16.7) _perfJank++;
    if (_perfAccumSec >= 0.5 && _perfFrames > 0) {
      _perf.value = _PerfSample(
        fps: _perfFrames / _perfAccumSec,
        avgMs: (_perfAccumSec / _perfFrames) * 1000.0,
        worstMs: _perfWorstMs,
        jank: _perfJank,
      );
      _perfAccumSec = 0.0;
      _perfFrames = 0;
      _perfWorstMs = 0.0;
      _perfJank = 0;
    }
  }

  static double _lerp(double a, double b, double t) =>
      a + (b - a) * t.clamp(0.0, 1.0);

  static double _lerpAngle(double a, double b, double t) {
    double diff = ((b - a + 540) % 360) - 180;
    return _wrapLon(a + diff * t.clamp(0.0, 1.0));
  }

  static double _wrapLon(double v) {
    double x = (v + 180) % 360;
    if (x < 0) x += 360;
    return x - 180;
  }

  @override
  void dispose() {
    _ticker.removeListener(_onFrame);
    _ticker.dispose();
    _perf.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxD = math.min(
            widget.size,
            math.min(constraints.maxWidth, constraints.maxHeight)
                .clamp(0.0, widget.size * 2),
          );
          final d = maxD.isFinite && maxD > 0 ? maxD : widget.size;
          final width = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : widget.size;
          return AnimatedBuilder(
            animation: widget.controller,
            builder: (context, _) {
              final state = widget.controller.state;
              return Semantics(
                label: widget.semanticLabel ??
                    (state.label != null
                        ? 'Globe focused on ${state.label}'
                        : 'Interactive globe'),
                image: true,
                child: SizedBox(
                  width: width,
                  height: d,
                  child: _perfEnabled
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            CustomPaint(
                              painter: _EarthPainter(
                                frame: _frame,
                                state: state,
                                repaint: _repaint,
                              ),
                            ),
                            Positioned(
                              left: 4,
                              top: 4,
                              child: _PerfOverlay(sample: _perf),
                            ),
                          ],
                        )
                      : CustomPaint(
                          painter: _EarthPainter(
                            frame: _frame,
                            state: state,
                            repaint: _repaint,
                          ),
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Mutable per-frame view parameters, advanced by the ticker without a
/// widget rebuild and read live by [_EarthPainter.paint].
class _GlobeFrame {
  double lon0 = 0.0; // center longitude facing viewer (degrees)
  double lat0 = 0.0; // center latitude facing viewer (degrees)
  double zoom = 1.0;
  double pan = 0.0; // 0 centered .. 1 slid right
  double cloudLon = 0.0; // extra cloud drift longitude (degrees)
}

class _EarthPainter extends CustomPainter {
  _EarthPainter({
    required this.frame,
    required this.state,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final _GlobeFrame frame;
  final GlobeInteractionState state;

  static const double _deg2rad = math.pi / 180.0;

  // Fixed sun direction in VIEW space (upper-left, toward the camera): the lit
  // crescent stays put while the Earth texture rotates under it — i.e. a fixed
  // sun with a rotating planet. Realistic and cheap.
  static const double _lightX = -0.5;
  static const double _lightY = 0.38;
  static const double _lightZ = 0.78;

  static final Float64List _identity4 = Float64List.fromList(<double>[
    1, 0, 0, 0, //
    0, 1, 0, 0, //
    0, 0, 1, 0, //
    0, 0, 0, 1, //
  ]);

  // ── Reusable Paints for the texture layers (shaders cached per image) ──
  final Paint _dayPaint = Paint()..filterQuality = FilterQuality.medium;
  final Paint _nightPaint = Paint()
    ..blendMode = BlendMode.plus
    ..filterQuality = FilterQuality.low;
  final Paint _cloudPaint = Paint()
    ..blendMode = BlendMode.screen
    ..filterQuality = FilterQuality.medium
    ..color = const Color(0xB3FFFFFF); // slightly soften cloud coverage
  final Map<int, ui.ImageShader> _shaderCache = <int, ui.ImageShader>{};

  // ── AURA accent / highlight Paints (allocated once, reused) ──
  static final Paint _rimPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.1
    ..color = AppColors.cyan.withOpacity(0.35);
  static final Paint _markerGlow = Paint()
    ..color = AppColors.cyan.withOpacity(0.35)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
  static final Paint _markerCore = Paint()..color = AppColors.cyan;
  static final Paint _connectorPaint = Paint()
    ..strokeWidth = 1.0
    ..color = AppColors.cyan.withOpacity(0.8);
  static final Paint _chipFill = Paint()
    ..color = AppColors.amoledBlack.withOpacity(0.72);
  static final Paint _chipStroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.8
    ..color = AppColors.cyan.withOpacity(0.6);
  static final Paint _regionRing = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0
    ..color = AppColors.violetLight.withOpacity(0.7);

  // Cached (center,radius)-dependent gradient shaders.
  final Paint _atmoPaint = Paint();
  final Paint _oceanPaint = Paint();
  Offset? _shaderCenter;
  double _shaderRadius = -1.0;

  // Cached laid-out label; re-laid-out only when the label text changes.
  TextPainter? _labelPainter;
  String? _labelText;

  ui.ImageShader _shaderFor(ui.Image image) {
    final int key = identityHashCode(image);
    return _shaderCache.putIfAbsent(
      key,
      () => ui.ImageShader(
          image, TileMode.clamp, TileMode.clamp, _identity4),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final lon0 = frame.lon0;
    final lat0 = frame.lat0;
    final zoom = frame.zoom;
    final pan = frame.pan;
    final diameter = math.min(size.width, size.height);

    final r = diameter / 2 * zoom.clamp(1.0, 12.0);
    final maxShift = size.width * 0.30;
    final cx = size.width / 2 + pan * maxShift;
    final cy = size.height / 2;
    final center = Offset(cx, cy);

    // Rebuild (center,radius)-dependent gradient shaders only on change.
    if (_shaderCenter != center || _shaderRadius != r) {
      _shaderCenter = center;
      _shaderRadius = r;
      _atmoPaint.shader = RadialGradient(
        colors: [
          AppColors.cyan.withOpacity(0.16),
          AppColors.violetLight.withOpacity(0.08),
          Colors.transparent,
        ],
        stops: const [0.86, 0.95, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: r * 1.16));
      _oceanPaint.shader = RadialGradient(
        center: const Alignment(-0.35, -0.35),
        colors: [
          const Color(0xFF0B2A4A),
          const Color(0xFF06182E),
          AppColors.amoledBlack,
        ],
        stops: const [0.0, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    }

    // Atmosphere bloom behind the planet.
    canvas.drawCircle(center, r * 1.16, _atmoPaint);

    final tex = EarthTextures.instance;
    if (tex.isReady) {
      _paintTexturedSphere(canvas, tex, lon0, lat0, r, cx, cy);
    } else {
      // Shaded ocean fallback until the real textures finish decoding.
      canvas.drawCircle(center, r, _oceanPaint);
    }

    // Thin AURA rim light (subtle — does not overpower the planet).
    canvas.drawCircle(center, r, _rimPaint);

    // Highlight marker + connector + label (projected with the SAME rotation).
    final loc = state.location;
    if (loc != null) {
      final proj =
          _project(loc.latitude, loc.longitude, lon0, lat0, r, center);
      if (proj != null) {
        _drawHighlight(canvas, size, center, r, proj, state);
      }
    }
  }

  void _paintTexturedSphere(Canvas canvas, EarthTextures tex, double lon0,
      double lat0, double r, double cx, double cy) {
    final mesh = _kSphere;
    final ui.Image surface = tex.surface!;

    // Transform A: the solid Earth (day surface + night lights share this).
    mesh.transform(
      lon0Deg: lon0,
      lat0Deg: lat0,
      radius: r,
      cx: cx,
      cy: cy,
      lightX: _lightX,
      lightY: _lightY,
      lightZ: _lightZ,
    );

    _dayPaint.shader = _shaderFor(surface);
    canvas.drawVertices(
      mesh.buildVertices(surface, mesh.dayColors),
      BlendMode.modulate,
      _dayPaint,
    );

    final ui.Image? night = tex.night;
    if (night != null) {
      _nightPaint.shader = _shaderFor(night);
      canvas.drawVertices(
        mesh.buildVertices(night, mesh.nightColors),
        BlendMode.modulate,
        _nightPaint,
      );
    }

    // Transform B: clouds drift slightly faster and sit a touch higher.
    final ui.Image? clouds = tex.clouds;
    if (clouds != null) {
      mesh.transform(
        lon0Deg: lon0 + frame.cloudLon,
        lat0Deg: lat0,
        radius: r * 1.012,
        cx: cx,
        cy: cy,
        lightX: _lightX,
        lightY: _lightY,
        lightZ: _lightZ,
      );
      _cloudPaint.shader = _shaderFor(clouds);
      canvas.drawVertices(
        mesh.buildVertices(clouds, mesh.dayColors),
        BlendMode.modulate,
        _cloudPaint,
      );
    }
  }

  /// Orthographic projection matching the mesh rotation; null on the far side.
  Offset? _project(double lat, double lon, double lon0, double lat0, double r,
      Offset center) {
    final latR = lat * _deg2rad;
    final lonR = lon * _deg2rad;
    final x = math.cos(latR) * math.sin(lonR);
    final y = math.sin(latR);
    final z = math.cos(latR) * math.cos(lonR);
    final a = lon0 * _deg2rad;
    final b = lat0 * _deg2rad;
    final ca = math.cos(a), sa = math.sin(a);
    final cb = math.cos(b), sb = math.sin(b);
    final x1 = x * ca - z * sa;
    final z1 = x * sa + z * ca;
    final y1 = y;
    final y2 = y1 * cb - z1 * sb;
    final z2 = y1 * sb + z1 * cb;
    final x2 = x1;
    if (z2 < 0) return null; // far hemisphere.
    return Offset(center.dx + x2 * r, center.dy - y2 * r);
  }

  void _drawHighlight(Canvas canvas, Size size, Offset center, double r,
      Offset proj, GlobeInteractionState state) {
    if (state.highlightType == GlobeHighlightType.region &&
        state.region != null) {
      final ringR = (state.region!.approxRadiusDegrees / 90.0) * r;
      canvas.drawCircle(proj, ringR.clamp(8.0, r), _regionRing);
    }

    canvas.drawCircle(proj, 9, _markerGlow);
    canvas.drawCircle(proj, 3.5, _markerCore);

    final label = state.label ?? state.location?.label ?? '';
    if (label.isEmpty) return;
    final chipAnchor = Offset(
      proj.dx + 22,
      (proj.dy - 34).clamp(14.0, size.height - 14.0),
    );
    canvas.drawLine(proj, chipAnchor, _connectorPaint);

    if (_labelText != label || _labelPainter == null) {
      _labelText = label;
      _labelPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.95),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: 140);
    }
    final tp = _labelPainter!;

    final chipRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(chipAnchor.dx, chipAnchor.dy - tp.height - 6,
          tp.width + 16, tp.height + 10),
      const Radius.circular(8),
    );
    canvas.drawRRect(chipRect, _chipFill);
    canvas.drawRRect(chipRect, _chipStroke);
    tp.paint(canvas, Offset(chipAnchor.dx + 8, chipAnchor.dy - tp.height - 1));
  }

  @override
  bool shouldRepaint(covariant _EarthPainter old) =>
      old.frame != frame || old.state != state;
}

/// DEV-ONLY perf sample published to [_PerfOverlay].
class _PerfSample {
  const _PerfSample({
    required this.fps,
    required this.avgMs,
    required this.worstMs,
    required this.jank,
  });
  static const _PerfSample zero =
      _PerfSample(fps: 0, avgMs: 0, worstMs: 0, jank: 0);
  final double fps;
  final double avgMs;
  final double worstMs;
  final int jank;
}

/// DEV-ONLY overlay. Rebuilds only when [sample] changes (~2x/sec), never per
/// frame, and is only mounted in debug builds when explicitly requested.
class _PerfOverlay extends StatelessWidget {
  const _PerfOverlay({required this.sample});
  final ValueListenable<_PerfSample> sample;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ValueListenableBuilder<_PerfSample>(
        valueListenable: sample,
        builder: (context, s, _) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.55),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.cyan.withOpacity(0.5)),
            ),
            child: Text(
              'FPS ${s.fps.toStringAsFixed(0)}  '
              'avg ${s.avgMs.toStringAsFixed(1)}ms  '
              'worst ${s.worstMs.toStringAsFixed(1)}ms  '
              'jank ${s.jank}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          );
        },
      ),
    );
  }
}
