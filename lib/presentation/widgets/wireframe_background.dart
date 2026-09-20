import 'dart:math';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Geometric wireframe/mesh/constellation background overlay.
///
/// Paints a subtle network of dots (nodes) connected by thin lines,
/// resembling a constellation/mesh pattern — matching the reference
/// design's background behind the glassmorphic cards.
///
/// Low opacity ensures it stays subtle and doesn't compete with content.
class WireframeBackground extends StatefulWidget {
  const WireframeBackground({
    super.key,
    this.opacity = 1.0,
    this.nodeCount = 30,
    this.lineDistance = 140,
  });

  /// Overall opacity multiplier for the entire overlay.
  final double opacity;

  /// Number of constellation nodes to render.
  final int nodeCount;

  /// Max distance for lines between nodes.
  final double lineDistance;

  @override
  State<WireframeBackground> createState() => _WireframeBackgroundState();
}

class _WireframeBackgroundState extends State<WireframeBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_Node> _nodes;
  Size? _canvasSize;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 30000),
    )..repeat();
    _nodes = [];
  }

  void _initNodes(Size size) {
    if (_canvasSize == size && _nodes.isNotEmpty) return;
    _canvasSize = size;
    final random = Random(42); // deterministic seed for consistent pattern
    _nodes = List.generate(widget.nodeCount, (i) {
      return _Node(
        x: random.nextDouble() * size.width,
        y: random.nextDouble() * size.height,
        vx: (random.nextDouble() - 0.5) * 0.15,
        vy: (random.nextDouble() - 0.5) * 0.15,
        radius: random.nextDouble() * 1.5 + 0.5,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _WireframePainter(
            nodes: _nodes,
            lineDistance: widget.lineDistance,
            opacity: widget.opacity,
            progress: _controller.value,
            canvasSize: _canvasSize ?? Size.zero,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _Node {
  double x;
  double y;
  final double vx;
  final double vy;
  final double radius;

  _Node({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.radius,
  });

  void move(Size size, double progress) {
    // Slow drift
    x += vx;
    y += vy;

    // Wrap around edges
    if (x < 0) x = size.width;
    if (x > size.width) x = 0;
    if (y < 0) y = size.height;
    if (y > size.height) y = 0;
  }
}

class _WireframePainter extends CustomPainter {
  _WireframePainter({
    required this.nodes,
    required this.lineDistance,
    required this.opacity,
    required this.progress,
    required this.canvasSize,
  });

  final List<_Node> nodes;
  final double lineDistance;
  final double opacity;
  final double progress;
  final Size canvasSize;

  @override
  void paint(Canvas canvas, Size size) {
    if (nodes.isEmpty || size == Size.zero) return;

    // Move nodes slightly
    for (final node in nodes) {
      node.move(size, progress);
    }

    final linePaint = Paint()
      ..color = AppColors.wireframeLine.withValues(alpha: AppColors.wireframeLine.a * opacity)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    final accentLinePaint = Paint()
      ..color = AppColors.wireframeAccent.withValues(alpha: AppColors.wireframeAccent.a * opacity)
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;

    final nodePaint = Paint()
      ..color = AppColors.wireframeNode.withValues(alpha: AppColors.wireframeNode.a * opacity)
      ..style = PaintingStyle.fill;

    // Draw lines between nearby nodes
    for (int i = 0; i < nodes.length; i++) {
      for (int j = i + 1; j < nodes.length; j++) {
        final dx = nodes[i].x - nodes[j].x;
        final dy = nodes[i].y - nodes[j].y;
        final dist = sqrt(dx * dx + dy * dy);

        if (dist < lineDistance) {
          final lineOpacity = (1.0 - dist / lineDistance).clamp(0.0, 1.0);
          final paint = (i + j) % 7 == 0 ? accentLinePaint : linePaint;
          canvas.drawLine(
            Offset(nodes[i].x, nodes[i].y),
            Offset(nodes[j].x, nodes[j].y),
            Paint()..color = paint.color.withValues(alpha: paint.color.a * lineOpacity),
          );
        }
      }
    }

    // Draw nodes as dots
    for (final node in nodes) {
      canvas.drawCircle(
        Offset(node.x, node.y),
        node.radius,
        nodePaint,
      );
    }

    // Draw a few faint geometric triangles for extra mesh feel
    if (nodes.length >= 3) {
      final trianglePaint = Paint()
        ..color = AppColors.wireframeLine.withValues(alpha: 0.03 * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.4;

      for (int i = 0; i < nodes.length - 2; i += 5) {
        final path = Path()
          ..moveTo(nodes[i].x, nodes[i].y)
          ..lineTo(nodes[i + 1].x, nodes[i + 1].y)
          ..lineTo(nodes[i + 2].x, nodes[i + 2].y)
          ..close();
        canvas.drawPath(path, trianglePaint);
      }
    }
  }

  @override
  bool shouldRepaint(_WireframePainter old) =>
      progress != old.progress || opacity != old.opacity;
}