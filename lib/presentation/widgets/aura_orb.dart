import 'dart:math';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Visual state of the AURA orb — maps to real assistant states.
enum AuraOrbState {
  /// No active task, waiting for input.
  idle,

  /// Microphone is open, listening for speech.
  listening,

  /// Processing input, waiting for AI response.
  thinking,

  /// AI is speaking / text is being read aloud.
  speaking,

  /// Executing a command / tool call.
  executing,

  /// An error occurred.
  error,
}

/// AURA Orb — the central glowing orb that reflects assistant state.
///
/// Rebuilt to match reference design: swirling nebula of interwoven
/// cyan + magenta neural fiber light patterns with soft diffused bloom glow.
/// NO inner state icons — the orb is a pure visual entity.
///
/// Each [AuraOrbState] has distinct fiber animation behavior:
/// - **idle**: slow drifting fibers, soft pulse
/// - **listening**: faster fiber rotation, expanding bloom rings
/// - **thinking**: rapid fiber weave, shimmer sweep
/// - **speaking**: pulsing bloom, breathing fibers
/// - **executing**: violet-magenta shift, rapid pulse
/// - **error**: red fibers, flickering
///
/// The widget is fully reusable — pass [state] from any provider.
class AuraOrb extends StatefulWidget {
  const AuraOrb({
    super.key,
    required this.state,
    this.size = 160,
    this.onTap,
  });

  /// Current assistant state driving the orb visuals.
  final AuraOrbState state;

  /// Diameter of the orb in logical pixels.
  final double size;

  /// Optional tap handler (e.g., start/stop listening).
  final VoidCallback? onTap;

  @override
  State<AuraOrb> createState() => _AuraOrbState();
}

class _AuraOrbState extends State<AuraOrb> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _fiberController;
  late AnimationController _ringController;
  late AnimationController _bloomController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _fiberController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _bloomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _configureAnimations();
  }

  @override
  void didUpdateWidget(AuraOrb old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) {
      _configureAnimations();
    }
  }

  void _configureAnimations() {
    _pulseController.stop();
    _fiberController.stop();
    _ringController.stop();
    _bloomController.stop();

    switch (widget.state) {
      case AuraOrbState.idle:
        _pulseController.duration = const Duration(milliseconds: 2400);
        _pulseController.repeat(reverse: true);
        _fiberController.duration = const Duration(milliseconds: 6000);
        _fiberController.repeat();
        _bloomController.repeat(reverse: true);
        break;

      case AuraOrbState.listening:
        _pulseController.duration = const Duration(milliseconds: 800);
        _pulseController.repeat(reverse: true);
        _fiberController.duration = const Duration(milliseconds: 2000);
        _fiberController.repeat();
        _ringController.repeat();
        _bloomController.duration = const Duration(milliseconds: 1500);
        _bloomController.repeat(reverse: true);
        break;

      case AuraOrbState.thinking:
        _pulseController.duration = const Duration(milliseconds: 1200);
        _pulseController.repeat(reverse: true);
        _fiberController.duration = const Duration(milliseconds: 1500);
        _fiberController.repeat();
        _bloomController.repeat(reverse: true);
        break;

      case AuraOrbState.speaking:
        _pulseController.duration = const Duration(milliseconds: 600);
        _pulseController.repeat(reverse: true);
        _fiberController.duration = const Duration(milliseconds: 3000);
        _fiberController.repeat();
        _bloomController.duration = const Duration(milliseconds: 1000);
        _bloomController.repeat(reverse: true);
        break;

      case AuraOrbState.executing:
        _pulseController.duration = const Duration(milliseconds: 500);
        _pulseController.repeat(reverse: true);
        _fiberController.duration = const Duration(milliseconds: 1200);
        _fiberController.repeat();
        _bloomController.repeat(reverse: true);
        break;

      case AuraOrbState.error:
        _pulseController.duration = const Duration(milliseconds: 400);
        _pulseController.repeat(reverse: true);
        _fiberController.duration = const Duration(milliseconds: 800);
        _fiberController.repeat();
        break;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fiberController.dispose();
    _ringController.dispose();
    _bloomController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;

    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: s,
        height: s,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ── Expanding bloom rings (listening state) ──
            if (widget.state == AuraOrbState.listening) ...[
              _buildExpandingRing(
                controller: _ringController,
                delay: 0.0,
                maxRadius: s * 0.52,
                color: AppColors.orbCyan,
              ),
              _buildExpandingRing(
                controller: _ringController,
                delay: 0.33,
                maxRadius: s * 0.56,
                color: AppColors.orbMagenta,
              ),
              _buildExpandingRing(
                controller: _ringController,
                delay: 0.66,
                maxRadius: s * 0.48,
                color: AppColors.orbCyanLight,
              ),
            ],

            // ── Outer bloom glow halo ──
            AnimatedBuilder(
              animation: Listenable.merge([_pulseController, _bloomController]),
              builder: (context, _) {
                final glowPulse = _pulseController.value;
                final bloomPulse = _bloomController.value;
                return Container(
                  width: s * (1.0 + bloomPulse * 0.08),
                  height: s * (1.0 + bloomPulse * 0.08),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _orbBloomCoreColor().withValues(alpha: 0.25 + glowPulse * 0.15),
                        _orbBloomMidColor().withValues(alpha: 0.12 + glowPulse * 0.08),
                        _orbBloomOuterColor().withValues(alpha: 0.04 + glowPulse * 0.03),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.3, 0.6, 1.0],
                    ),
                  ),
                );
              },
            ),

            // ── Neural fiber painter (the swirling nebula) ──
            AnimatedBuilder(
              animation: Listenable.merge([_fiberController, _pulseController]),
              builder: (context, _) {
                return CustomPaint(
                  size: Size(s * 0.85, s * 0.85),
                  painter: _NeuralFiberPainter(
                    progress: _fiberController.value,
                    pulse: _pulseController.value,
                    state: widget.state,
                    size: s * 0.85,
                  ),
                );
              },
            ),

            // ── Core orb sphere with gradient ──
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                final scale = 1.0 + _pulseController.value * 0.04;
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: s * 0.38,
                    height: s * 0.38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _orbCoreColor().withValues(alpha: 0.9),
                          _orbMidColor().withValues(alpha: 0.6),
                          _orbOuterColor().withValues(alpha: 0.2),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.35, 0.7, 1.0],
                        center: Alignment.center,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _orbCoreColor().withValues(alpha: 0.4 + _pulseController.value * 0.2),
                          blurRadius: 32,
                          spreadRadius: 4,
                        ),
                        BoxShadow(
                          color: _orbBloomCoreColor().withValues(alpha: 0.15),
                          blurRadius: 48,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            // ── Bright center point ──
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                return Container(
                  width: s * 0.08 + _pulseController.value * s * 0.02,
                  height: s * 0.08 + _pulseController.value * s * 0.02,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.orbFiberCore.withValues(alpha: 0.95),
                        _orbCoreColor().withValues(alpha: 0.7),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.4, 1.0],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Expanding ring for listening state ──
  Widget _buildExpandingRing({
    required AnimationController controller,
    required double delay,
    required double maxRadius,
    required Color color,
  }) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final raw = (controller.value + delay) % 1.0;
        final opacity = (1.0 - raw).clamp(0.0, 1.0);
        final radius = maxRadius * raw;

        return CustomPaint(
          size: Size(maxRadius * 2, maxRadius * 2),
          painter: _RingPainter(
            radius: radius,
            color: color.withValues(alpha: opacity * 0.3),
            strokeWidth: 1.5,
          ),
        );
      },
    );
  }

  // ── State-specific orb colors ──
  Color _orbCoreColor() {
    switch (widget.state) {
      case AuraOrbState.idle:
        return AppColors.orbStart;
      case AuraOrbState.listening:
        return AppColors.orbCyan;
      case AuraOrbState.thinking:
        return AppColors.violetLight;
      case AuraOrbState.speaking:
        return AppColors.orbEnd;
      case AuraOrbState.executing:
        return AppColors.magenta;
      case AuraOrbState.error:
        return AppColors.red;
    }
  }

  Color _orbMidColor() {
    switch (widget.state) {
      case AuraOrbState.idle:
        return AppColors.orbMiddle;
      case AuraOrbState.listening:
        return AppColors.orbCyanLight;
      case AuraOrbState.thinking:
        return AppColors.orbMiddle;
      case AuraOrbState.speaking:
        return AppColors.orbMiddle;
      case AuraOrbState.executing:
        return AppColors.orbStart;
      case AuraOrbState.error:
        return AppColors.red.withValues(alpha: 0.6);
    }
  }

  Color _orbOuterColor() {
    switch (widget.state) {
      case AuraOrbState.idle:
        return AppColors.orbEnd;
      case AuraOrbState.listening:
        return AppColors.orbMagenta;
      case AuraOrbState.thinking:
        return AppColors.orbEnd;
      case AuraOrbState.speaking:
        return AppColors.orbStart;
      case AuraOrbState.executing:
        return AppColors.purple;
      case AuraOrbState.error:
        return AppColors.red.withValues(alpha: 0.3);
    }
  }

  // ── Bloom halo colors (softer, diffused) ──
  Color _orbBloomCoreColor() {
    switch (widget.state) {
      case AuraOrbState.idle:
        return AppColors.violet;
      case AuraOrbState.listening:
        return AppColors.cyan;
      case AuraOrbState.thinking:
        return AppColors.violetLight;
      case AuraOrbState.speaking:
        return AppColors.magenta;
      case AuraOrbState.executing:
        return AppColors.magenta;
      case AuraOrbState.error:
        return AppColors.red;
    }
  }

  Color _orbBloomMidColor() {
    switch (widget.state) {
      case AuraOrbState.idle:
        return AppColors.orbMagenta;
      case AuraOrbState.listening:
        return AppColors.orbCyan;
      case AuraOrbState.thinking:
        return AppColors.orbMagenta;
      case AuraOrbState.speaking:
        return AppColors.violet;
      case AuraOrbState.executing:
        return AppColors.purple;
      case AuraOrbState.error:
        return AppColors.red.withValues(alpha: 0.5);
    }
  }

  Color _orbBloomOuterColor() {
    switch (widget.state) {
      case AuraOrbState.idle:
        return AppColors.orbEnd;
      case AuraOrbState.listening:
        return AppColors.orbCyanLight;
      case AuraOrbState.thinking:
        return AppColors.orbEnd;
      case AuraOrbState.speaking:
        return AppColors.orbMagenta;
      case AuraOrbState.executing:
        return AppColors.orbStart;
      case AuraOrbState.error:
        return AppColors.red.withValues(alpha: 0.2);
    }
  }
}

/// Painter for expanding concentric rings.
class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.radius,
    required this.color,
    required this.strokeWidth,
  });

  final double radius;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      radius,
      paint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      radius != old.radius || color != old.color;
}

/// Neural fiber painter — draws the swirling nebula of interwoven
/// cyan + magenta light fibers resembling neural network/fiber-optic patterns.
///
/// This is the visual core of the AURA orb per the reference design.
/// Uses bezier curves to create flowing fiber-like paths that rotate
/// and interweave, with per-fiber color interpolation between cyan and magenta.
class _NeuralFiberPainter extends CustomPainter {
  _NeuralFiberPainter({
    required this.progress,
    required this.pulse,
    required this.state,
    required this.size,
  });

  final double progress;
  final double pulse;
  final AuraOrbState state;
  final double size;

  // Deterministic fiber definitions — each fiber is defined by control points
  // that rotate around the center based on progress.
  static const int _fiberCount = 18;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw each fiber as a curved path
    for (int i = 0; i < _fiberCount; i++) {
      final fiberProgress = (progress + i / _fiberCount) % 1.0;
      final angle = fiberProgress * 2 * pi;

      // Fiber endpoints rotate around the orb
      final startAngle = angle + (i * pi / _fiberCount);
      final endAngle = angle + pi + (i * pi / _fiberCount * 0.7);

      // Control point offset — creates the weaving/interweaving effect
      final cpOffset = sin(angle * 2 + i) * radius * 0.3;
      final cpAngle = angle + pi / 2 + (i * 0.3);

      final startPoint = Offset(
        center.dx + cos(startAngle) * radius * (0.5 + pulse * 0.1),
        center.dy + sin(startAngle) * radius * (0.5 + pulse * 0.1),
      );
      final endPoint = Offset(
        center.dx + cos(endAngle) * radius * (0.5 + pulse * 0.1),
        center.dy + sin(endAngle) * radius * (0.5 + pulse * 0.1),
      );
      final controlPoint = Offset(
        center.dx + cos(cpAngle) * cpOffset,
        center.dy + sin(cpAngle) * cpOffset,
      );

      // Interpolate color between cyan and magenta based on fiber index
      final isCyanFiber = i % 3 != 0;
      final fiberColor = isCyanFiber
          ? _fiberCyanColor().withValues(alpha: _fiberAlpha())
          : _fiberMagentaColor().withValues(alpha: _fiberAlpha());

      final paint = Paint()
        ..color = fiberColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = _fiberWidth()
        ..strokeCap = StrokeCap.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, _fiberBlur());

      final path = Path()
        ..moveTo(startPoint.dx, startPoint.dy)
        ..quadraticBezierTo(
          controlPoint.dx,
          controlPoint.dy,
          endPoint.dx,
          endPoint.dy,
        );

      canvas.drawPath(path, paint);

      // Draw a second, thinner bright core line for the fiber
      final corePaint = Paint()
        ..color = (isCyanFiber
                ? AppColors.orbCyanLight
                : AppColors.orbMagentaLight)
            .withValues(alpha: _fiberAlpha() * 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _fiberWidth() * 0.4
        ..strokeCap = StrokeCap.round;

      canvas.drawPath(path, corePaint);
    }

    // Draw small bright nodes at intersections
    for (int i = 0; i < 8; i++) {
      final nodeAngle = (progress + i / 8) * 2 * pi;
      final nodeRadius = radius * (0.25 + 0.15 * sin(nodeAngle * 3 + i));
      final nodePos = Offset(
        center.dx + cos(nodeAngle) * nodeRadius,
        center.dy + sin(nodeAngle) * nodeRadius,
      );

      final nodePaint = Paint()
        ..color = AppColors.orbFiberCore.withValues(alpha: 0.3 + pulse * 0.2)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

      canvas.drawCircle(nodePos, 2.5 + pulse * 1.5, nodePaint);
    }
  }

  double _fiberAlpha() {
    switch (state) {
      case AuraOrbState.idle:
        return 0.35 + pulse * 0.15;
      case AuraOrbState.listening:
        return 0.5 + pulse * 0.2;
      case AuraOrbState.thinking:
        return 0.45 + pulse * 0.2;
      case AuraOrbState.speaking:
        return 0.4 + pulse * 0.25;
      case AuraOrbState.executing:
        return 0.5 + pulse * 0.2;
      case AuraOrbState.error:
        return 0.3 + pulse * 0.15;
    }
  }

  double _fiberWidth() {
    switch (state) {
      case AuraOrbState.idle:
        return 1.8;
      case AuraOrbState.listening:
        return 2.2;
      case AuraOrbState.thinking:
        return 2.0;
      case AuraOrbState.speaking:
        return 1.8;
      case AuraOrbState.executing:
        return 2.0;
      case AuraOrbState.error:
        return 1.5;
    }
  }

  double _fiberBlur() {
    switch (state) {
      case AuraOrbState.idle:
        return 2.0;
      case AuraOrbState.listening:
        return 1.5;
      case AuraOrbState.thinking:
        return 1.8;
      case AuraOrbState.speaking:
        return 2.5;
      case AuraOrbState.executing:
        return 1.5;
      case AuraOrbState.error:
        return 2.0;
    }
  }

  Color _fiberCyanColor() {
    switch (state) {
      case AuraOrbState.idle:
        return AppColors.orbCyan;
      case AuraOrbState.listening:
        return AppColors.cyanLight;
      case AuraOrbState.thinking:
        return AppColors.orbCyan;
      case AuraOrbState.speaking:
        return AppColors.orbCyan;
      case AuraOrbState.executing:
        return AppColors.orbCyan;
      case AuraOrbState.error:
        return AppColors.red;
    }
  }

  Color _fiberMagentaColor() {
    switch (state) {
      case AuraOrbState.idle:
        return AppColors.orbMagenta;
      case AuraOrbState.listening:
        return AppColors.orbMagentaLight;
      case AuraOrbState.thinking:
        return AppColors.orbMagenta;
      case AuraOrbState.speaking:
        return AppColors.orbMagenta;
      case AuraOrbState.executing:
        return AppColors.orbMagentaLight;
      case AuraOrbState.error:
        return AppColors.red;
    }
  }

  @override
  bool shouldRepaint(_NeuralFiberPainter old) =>
      progress != old.progress || pulse != old.pulse || state != old.state;
}