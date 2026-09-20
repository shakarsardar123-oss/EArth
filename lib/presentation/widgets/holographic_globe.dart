/// holographic_globe.dart
/// AURA Assistant – Holographic Globe Widget
///
/// Lightweight, dependency-free "holographic Earth" visual for the AURA
/// Home screen. Pure CustomPainter/AnimationController implementation —
/// no 3D engine, no heavy packages — to stay performant on Android.
///
/// Design intent (per redesign brief):
///   • Futuristic / holographic / neon / dimensional / interactive
///   • Reacts to the SAME state enum already driving [AuraWaveForm]
///     (AuraWaveFormState) — no second, parallel state machine.
///   • Exposes a clean controller so the existing AURA agent/command
///     pipeline can later drive globe behavior (rotateToLocation,
///     showLocation, showImageOverlay, clearOverlay) without this
///     widget ever generating commands itself.
library;

import 'dart:math';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'aura_wave_form.dart' show AuraWaveFormState;

/// A named location to highlight on the globe.
///
/// Coordinates are plain lat/long degrees; the caller (agent pipeline)
/// decides what "location" means — this widget has no built-in geocoding
/// or hardcoded places.
class GlobeLocation {
  const GlobeLocation({
    required this.label,
    required this.latitude,
    required this.longitude,
  });

  final String label;
  final double latitude;
  final double longitude;
}

/// Controller that exposes the globe's public interaction surface.
///
/// This is intentionally a thin, dumb surface: it only stores the
/// requested visual state. Wiring it to real commands (e.g. "Show
/// America") is left to the existing AURA agent/command pipeline —
/// this controller does not interpret speech or call any AI provider.
class HolographicGlobeController extends ChangeNotifier {
  GlobeLocation? _highlighted;
  String? _overlayImageUrl;
  double _targetRotation = 0.0;

  GlobeLocation? get highlightedLocation => _highlighted;
  String? get overlayImageUrl => _overlayImageUrl;
  double get targetRotation => _targetRotation;

  /// Rotate the globe to face the given longitude (degrees).
  /// Call this from the agent/command layer, e.g. after a tool
  /// resolves "show America" to a longitude.
  void rotateToLocation(double longitudeDegrees) {
    _targetRotation = longitudeDegrees * pi / 180.0;
    notifyListeners();
  }

  /// Highlight a named location with a marker on the globe surface.
  void showLocation(GlobeLocation location) {
    _highlighted = location;
    _targetRotation = location.longitude * pi / 180.0;
    notifyListeners();
  }

  /// Show an image overlay near the current highlighted location
  /// (e.g. a photo of the requested place). URL/asset resolution is
  /// the caller's responsibility.
  void showImageOverlay(String imageUrl) {
    _overlayImageUrl = imageUrl;
    notifyListeners();
  }

  /// Clear any highlight/overlay, returning the globe to its idle look.
  void clearOverlay() {
    _highlighted = null;
    _overlayImageUrl = null;
    notifyListeners();
  }
}

/// Holographic globe widget. Purely visual + a controller hook;
/// does not own or duplicate AURA's voice/agent state.
class HolographicGlobe extends StatefulWidget {
  const HolographicGlobe({
    super.key,
    required this.state,
    this.controller,
    this.size = 180,
  });

  /// Reuses the wave form's state enum so the globe and the wave form
  /// always agree on what AURA is currently doing.
  final AuraWaveFormState state;

  /// Optional controller for future agent-driven interaction.
  final HolographicGlobeController? controller;

  /// Diameter of the globe in logical pixels.
  final double size;

  @override
  State<HolographicGlobe> createState() => _HolographicGlobeState();
}

class _HolographicGlobeState extends State<HolographicGlobe>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;
  double _currentRotation = 0.0;

  @override
  void initState() {
    super.initState();
    // Single controller drives idle auto-rotation AND state-reactive
    // pulse speed — avoids stacking multiple always-on controllers.
    _rotationController = AnimationController(
      vsync: this,
      duration: _durationForState(widget.state),
    )..repeat();
    widget.controller?.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant HolographicGlobe oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _rotationController.duration = _durationForState(widget.state);
      _rotationController.repeat();
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onControllerChanged);
      widget.controller?.addListener(_onControllerChanged);
    }
  }

  void _onControllerChanged() {
    final target = widget.controller?.targetRotation;
    if (target != null) {
      setState(() => _currentRotation = target);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onControllerChanged);
    _rotationController.dispose();
    super.dispose();
  }

  Duration _durationForState(AuraWaveFormState state) {
    switch (state) {
      case AuraWaveFormState.idle:
        return const Duration(milliseconds: 14000);
      case AuraWaveFormState.listening:
        return const Duration(milliseconds: 8000);
      case AuraWaveFormState.processing:
        return const Duration(milliseconds: 3000);
      case AuraWaveFormState.speaking:
        return const Duration(milliseconds: 6000);
      case AuraWaveFormState.error:
        return const Duration(milliseconds: 10000);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.state == AuraWaveFormState.error
        ? AppColors.waveFormErrorRed
        : AppColors.cyan;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _rotationController,
        builder: (context, _) {
          final spin = _rotationController.value * 2 * pi;
          return SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: _GlobePainter(
                spin: spin + _currentRotation,
                accent: accent,
                secondary: AppColors.violetLight,
                state: widget.state,
                highlighted: widget.controller?.highlightedLocation,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GlobePainter extends CustomPainter {
  _GlobePainter({
    required this.spin,
    required this.accent,
    required this.secondary,
    required this.state,
    required this.highlighted,
  });

  final double spin;
  final Color accent;
  final Color secondary;
  final AuraWaveFormState state;
  final GlobeLocation? highlighted;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 * 0.82;

    // Outer soft bloom.
    final bloomPaint = Paint()
      ..color = accent.withOpacity(0.14)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
    canvas.drawCircle(center, radius * 1.05, bloomPaint);

    // Sphere outline.
    final outlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = accent.withOpacity(0.55);
    canvas.drawCircle(center, radius, outlinePaint);

    // Latitude rings (ellipses that flatten near the poles).
    final latPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = accent.withOpacity(0.28);
    for (int i = 1; i < 5; i++) {
      final t = i / 5;
      final yOffset = radius * (t * 2 - 1) * 0.8;
      final ringRadiusY = radius * sqrt(max(0.0, 1 - (t * 2 - 1) * (t * 2 - 1))) ;
      canvas.drawOval(
        Rect.fromCenter(
          center: center.translate(0, yOffset),
          width: radius * 2,
          height: ringRadiusY * 0.9,
        ),
        latPaint,
      );
    }

    // Longitude meridians — rotating ellipses to fake 3D spin.
    final lonPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = secondary.withOpacity(0.32);
    for (int i = 0; i < 6; i++) {
      final angle = spin + (i * pi / 6);
      final squash = cos(angle).abs().clamp(0.06, 1.0);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(squash, 1.0);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: radius * 2, height: radius * 2),
        lonPaint,
      );
      canvas.restore();
    }

    // Core glow — pulses faster while processing/speaking.
    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [accent.withOpacity(0.35), accent.withOpacity(0.0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.6));
    canvas.drawCircle(center, radius * 0.6, corePaint);

    // Optional highlighted-location marker.
    if (highlighted != null) {
      final markerAngle = spin + highlighted!.longitude * pi / 180.0;
      final markerPos = center +
          Offset(cos(markerAngle), sin(highlighted!.latitude * pi / 180.0) * 0.6) *
              radius;
      final markerPaint = Paint()..color = accent;
      canvas.drawCircle(markerPos, 3.5, markerPaint);
      final markerGlow = Paint()
        ..color = accent.withOpacity(0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(markerPos, 7, markerGlow);
    }
  }

  @override
  bool shouldRepaint(covariant _GlobePainter oldDelegate) {
    return oldDelegate.spin != spin ||
        oldDelegate.accent != accent ||
        oldDelegate.highlighted != highlighted;
  }
}
