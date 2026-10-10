import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/voice/voice_service.dart' show VoiceState;
import '../../core/providers/phase3_connection_points.dart';
import '../../core/theme/app_colors_adaptive.dart';

/// AURA voice waveform visualizer — animated bars.
///
/// Visual-only simulation. Phase 3 will connect to real audio data.
class VoiceVisualizer extends ConsumerStatefulWidget {
  const VoiceVisualizer({
    super.key,
    this.barCount = 32,
    this.barWidth = 3,
    this.maxBarHeight = 48,
    this.spacing = 2,
    this.color,
  });

  final int barCount;
  final double barWidth;
  final double maxBarHeight;
  final double spacing;
  final Color? color;

  @override
  ConsumerState<VoiceVisualizer> createState() => _VoiceVisualizerState();
}

class _VoiceVisualizerState extends ConsumerState<VoiceVisualizer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<double> _barHeights;
  final _random = Random(42); // Fixed seed for consistent pattern

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _barHeights = List.filled(widget.barCount, 0.0);
    _controller.addListener(_updateBars);
  }

  void _updateBars() {
    final voiceState = ref.read(voiceStateProvider);
    if (voiceState != VoiceState.listening && voiceState != VoiceState.speaking) {
      // Decay bars when not active
      for (int i = 0; i < _barHeights.length; i++) {
        _barHeights[i] *= 0.85;
        if (_barHeights[i] < 1) _barHeights[i] = 0;
      }
    } else {
      // Simulate waveform
      for (int i = 0; i < _barHeights.length; i++) {
        final target = _random.nextDouble() * widget.maxBarHeight;
        final speed = voiceState == VoiceState.listening ? 0.4 : 0.2;
        _barHeights[i] += (target - _barHeights[i]) * speed;
      }
    }
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(VoiceVisualizer old) {
    super.didUpdateWidget(old);
    final voiceState = ref.read(voiceStateProvider);
    if ((voiceState == VoiceState.listening || voiceState == VoiceState.speaking) &&
        !_controller.isAnimating) {
      _controller.repeat();
    } else if (voiceState == VoiceState.idle && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_updateBars);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final voiceState = ref.watch(voiceStateProvider);
    final shouldAnimate =
        voiceState == VoiceState.listening ||
        voiceState == VoiceState.speaking;

    if (shouldAnimate) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else if (_controller.isAnimating) {
      _controller.stop();
    }

    if (voiceState == VoiceState.idle ||
        voiceState == VoiceState.processing) {
      if (voiceState == VoiceState.idle) {
        return _buildIdleLine();
      }
      return _buildProcessingDots();
    }

    final barColor = widget.color ?? AuraColors.accentOf(context);

    return CustomPaint(
      size: Size(
        widget.barCount * (widget.barWidth + widget.spacing),
        widget.maxBarHeight,
      ),
      painter: _WaveformPainter(
        barHeights: _barHeights,
        barWidth: widget.barWidth,
        spacing: widget.spacing,
        color: barColor,
        maxBarHeight: widget.maxBarHeight,
      ),
    );
  }

  Widget _buildIdleLine() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      height: 2,
      decoration: BoxDecoration(
        color: cs.outline.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }

  Widget _buildProcessingDots() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) =>
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: _PulsingDot(
            color: cs.primary.withValues(alpha: 0.5),
            delay: Duration(milliseconds: i * 300),
          ),
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color, this.delay = Duration.zero});
  final Color color;
  final Duration delay;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    Future.delayed(widget.delay, () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.barHeights,
    required this.barWidth,
    required this.spacing,
    required this.color,
    required this.maxBarHeight,
  });

  final List<double> barHeights;
  final double barWidth;
  final double spacing;
  final Color color;
  final double maxBarHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    final centerY = size.height / 2;

    for (int i = 0; i < barHeights.length; i++) {
      final bx = i * (barWidth + spacing);

      final rrect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(bx + barWidth / 2, centerY),
          width: barWidth,
          height: barHeights[i].clamp(2.0, maxBarHeight),
        ),
        Radius.circular(barWidth / 2),
      );
      canvas.drawRRect(rrect, paint);
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) => true;
}
