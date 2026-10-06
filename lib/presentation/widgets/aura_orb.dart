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

            // ── Glass holographic outer bloom ──
            AnimatedBuilder(
              animation: Listenable.merge([
                _pulseController,
                _bloomController,
              ]),
              builder: (context, _) {
                final pulse = _pulseController.value;
                final bloom = _bloomController.value;

                return Transform.scale(
                  scale: 1.0 + bloom * 0.045,
                  child: Container(
                    width: s * 0.94,
                    height: s * 0.94,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: const Alignment(-0.22, -0.28),
                        radius: 0.9,
                        colors: [
                          AppColors.orbCyan.withValues(
                            alpha: 0.035 + pulse * 0.025,
                          ),
                          AppColors.violet.withValues(
                            alpha: 0.055 + pulse * 0.025,
                          ),
                          AppColors.orbMagenta.withValues(
                            alpha: 0.035 + bloom * 0.025,
                          ),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.42, 0.72, 1.0],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.orbCyan.withValues(
                            alpha: 0.10 + pulse * 0.05,
                          ),
                          blurRadius: 28 + bloom * 12,
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: AppColors.orbMagenta.withValues(
                            alpha: 0.08 + bloom * 0.04,
                          ),
                          blurRadius: 42 + bloom * 14,
                          spreadRadius: 4,
                        ),
                      ],
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

            // ── Transparent glass depth layer ──
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                final pulse = _pulseController.value;

                return Transform.scale(
                  scale: 1.0 + pulse * 0.018,
                  child: Container(
                    width: s * 0.82,
                    height: s * 0.82,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: const Alignment(-0.28, -0.34),
                        radius: 0.92,
                        colors: [
                          Colors.white.withValues(
                            alpha: 0.025 + pulse * 0.01,
                          ),
                          AppColors.orbCyan.withValues(
                            alpha: 0.028 + pulse * 0.012,
                          ),
                          AppColors.violet.withValues(
                            alpha: 0.035 + pulse * 0.012,
                          ),
                          AppColors.orbMagenta.withValues(
                            alpha: 0.018,
                          ),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.24, 0.52, 0.76, 1.0],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(
                          alpha: 0.075 + pulse * 0.025,
                        ),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 18,
                          spreadRadius: -5,
                        ),
                        BoxShadow(
                          color: AppColors.violet.withValues(alpha: 0.08),
                          blurRadius: 30,
                          spreadRadius: 1,
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

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // ── Soft holographic inner atmosphere ──
    final atmospherePaint = Paint()
      ..shader = RadialGradient(
        center: Alignment(
          -0.25 + sin(progress * 2 * pi) * 0.12,
          -0.30 + cos(progress * 2 * pi) * 0.10,
        ),
        radius: 0.92,
        colors: [
          AppColors.orbCyanLight.withValues(alpha: 0.22 + pulse * 0.08),
          AppColors.orbCyan.withValues(alpha: 0.12),
          AppColors.violet.withValues(alpha: 0.20),
          AppColors.orbMagenta.withValues(alpha: 0.14),
          Colors.transparent,
        ],
        stops: const [0.0, 0.22, 0.55, 0.78, 1.0],
      ).createShader(
        Rect.fromCircle(center: center, radius: radius),
      );

    canvas.drawCircle(center, radius * 0.94, atmospherePaint);

    // ── Moving holographic light ──
    final sweepAngle = progress * 2 * pi;
    final lightCenter = Offset(
      center.dx + cos(sweepAngle) * radius * 0.42,
      center.dy + sin(sweepAngle) * radius * 0.42,
    );

    final lightPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          _holographicAccent().withValues(alpha: 0.42 + pulse * 0.16),
          _holographicAccent().withValues(alpha: 0.14),
          Colors.transparent,
        ],
        stops: const [0.0, 0.32, 1.0],
      ).createShader(
        Rect.fromCircle(
          center: lightCenter,
          radius: radius * 0.58,
        ),
      );

    canvas.drawCircle(lightCenter, radius * 0.58, lightPaint);

    // ── Glass rim ──
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.018
      ..shader = SweepGradient(
        transform: GradientRotation(progress * 2 * pi),
        colors: [
          Colors.white.withValues(alpha: 0.55),
          AppColors.orbCyanLight.withValues(alpha: 0.28),
          AppColors.violetLight.withValues(alpha: 0.42),
          AppColors.orbMagentaLight.withValues(alpha: 0.35),
          Colors.white.withValues(alpha: 0.52),
        ],
      ).createShader(
        Rect.fromCircle(center: center, radius: radius * 0.91),
      );

    canvas.drawCircle(center, radius * 0.91, rimPaint);

    // ── Thin secondary holographic rim ──
    final innerRimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.008
      ..color = Colors.white.withValues(alpha: 0.20 + pulse * 0.08);

    canvas.drawCircle(center, radius * 0.84, innerRimPaint);

    // ── Curved glass reflections ──
    final reflectionPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = radius * 0.045
      ..color = Colors.white.withValues(alpha: 0.16 + pulse * 0.05)
      ..maskFilter = MaskFilter.blur(
        BlurStyle.normal,
        radius * 0.025,
      );

    final reflectionPath = Path()
      ..moveTo(
        center.dx - radius * 0.54,
        center.dy - radius * 0.36,
      )
      ..quadraticBezierTo(
        center.dx - radius * 0.12,
        center.dy - radius * 0.70,
        center.dx + radius * 0.30,
        center.dy - radius * 0.56,
      );

    canvas.drawPath(reflectionPath, reflectionPaint);

    // ── Small specular highlight ──
    final highlightPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.75),
          Colors.white.withValues(alpha: 0.22),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(
            center.dx - radius * 0.30,
            center.dy - radius * 0.38,
          ),
          radius: radius * 0.16,
        ),
      );

    canvas.drawCircle(
      Offset(
        center.dx - radius * 0.30,
        center.dy - radius * 0.38,
      ),
      radius * 0.16,
      highlightPaint,
    );

    // ── Subtle holographic particles ──
    for (int i = 0; i < 9; i++) {
      final angle = progress * 2 * pi + i * (2 * pi / 9);
      final orbitRadius =
          radius * (0.42 + 0.08 * sin(i * 2.1 + progress * 4));

      final particlePosition = Offset(
        center.dx + cos(angle) * orbitRadius,
        center.dy + sin(angle) * orbitRadius,
      );

      final particlePaint = Paint()
        ..color = (i.isEven
                ? AppColors.orbCyanLight
                : AppColors.orbMagentaLight)
            .withValues(alpha: 0.16 + pulse * 0.12)
        ..maskFilter = const MaskFilter.blur(
          BlurStyle.normal,
          2,
        );

      canvas.drawCircle(
        particlePosition,
        radius * 0.018 + pulse * radius * 0.006,
        particlePaint,
      );
    }
  }

  Color _holographicAccent() {
    switch (state) {
      case AuraOrbState.idle:
        return AppColors.violet;
      case AuraOrbState.listening:
        return AppColors.orbCyan;
      case AuraOrbState.thinking:
        return AppColors.purple;
      case AuraOrbState.speaking:
        return AppColors.orbMagenta;
      case AuraOrbState.executing:
        return AppColors.violetLight;
      case AuraOrbState.error:
        return AppColors.red;
    }
  }

  @override
  bool shouldRepaint(_NeuralFiberPainter old) =>
      progress != old.progress ||
      pulse != old.pulse ||
      state != old.state;
}

