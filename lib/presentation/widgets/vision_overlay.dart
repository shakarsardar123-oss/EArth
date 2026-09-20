import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/entities/vision/vision_entities.dart';
import '../../core/errors/result.dart';

/// Overlay widget that renders vision analysis results on top of the camera preview.
///
/// Draws bounding boxes (rect, circle, arrow, point) and labels over the
/// camera feed, mapping normalized coordinates (0–1) to screen pixels.
class VisionOverlay extends StatelessWidget {
  const VisionOverlay({
    super.key,
    required this.result,
    this.previewSize,
    this.onTargetTap,
  });

  /// The vision result containing targets to render.
  final VisionResult result;

  /// Optional preview size hint (width, height in logical pixels).
  /// If null, uses the widget's own size.
  final Size? previewSize;

  /// Callback when a target is tapped.
  final void Function(VisionTarget)? onTargetTap;

  @override
  Widget build(BuildContext context) {
    if (!result.isSuccess || result.targets.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = previewSize ?? Size(constraints.maxWidth, constraints.maxHeight);
        return Stack(
          children: result.targets.map((target) {
            if (target.boundingBox == null) return const SizedBox.shrink();
            return _buildTargetOverlay(target, size);
          }).toList(),
        );
      },
    );
  }

  Widget _buildTargetOverlay(VisionTarget target, Size canvasSize) {
    final box = target.boundingBox!;
    final color = _resolveColor(box);

    return Positioned(
      left: box.x * canvasSize.width,
      top: box.y * canvasSize.height,
      width: box.width * canvasSize.width,
      height: box.height * canvasSize.height,
      child: GestureDetector(
        onTap: () => onTargetTap?.call(target),
        child: CustomPaint(
          painter: _OverlayPainter(
            box: box,
            color: color,
            canvasSize: canvasSize,
          ),
          child: _buildLabel(box, color),
        ),
      ),
    );
  }

  Widget _buildLabel(BoundingBox box, Color color) {
    if (!box.showLabel && !box.showConfidence) {
      return const SizedBox.shrink();
    }

    final labelText = <String>[
      if (box.showLabel && box.label != null) box.label!,
      if (box.showConfidence && box.confidence != null)
        '${(box.confidence! * 100).toInt()}%',
    ].join(' ');

    if (labelText.isEmpty) return const SizedBox.shrink();

    // Determine label position.
    final alignment = switch (box.labelPosition) {
      LabelPosition.topLeft     => Alignment.topLeft,
      LabelPosition.topCenter   => Alignment.topCenter,
      LabelPosition.topRight    => Alignment.topRight,
      LabelPosition.bottomLeft  => Alignment.bottomLeft,
      LabelPosition.bottomCenter => Alignment.bottomCenter,
      LabelPosition.bottomRight => Alignment.bottomRight,
      LabelPosition.center      => Alignment.center,
    };

    return Align(
      alignment: alignment,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.75),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          labelText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Color _resolveColor(BoundingBox box) {
    if (box.color != null) {
      return Color(box.color!);
    }
    return switch (box.style) {
      BoundingBoxStyle.rect   => Colors.cyanAccent,
      BoundingBoxStyle.circle  => Colors.greenAccent,
      BoundingBoxStyle.arrow   => Colors.orangeAccent,
      BoundingBoxStyle.point   => Colors.redAccent,
    };
  }
}

/// CustomPainter for rendering vision overlay shapes.
class _OverlayPainter extends CustomPainter {
  _OverlayPainter({
    required this.box,
    required this.color,
    required this.canvasSize,
  });

  final BoundingBox box;
  final Color color;
  final Size canvasSize;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = box.lineWidth
      ..isAntiAlias = true;

    final fillPaint = Paint()
      ..color = color.withOpacity(box.fillOpacity)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    switch (box.style) {
      case BoundingBoxStyle.rect:
        _drawRect(canvas, size, paint, fillPaint);
      case BoundingBoxStyle.circle:
        _drawCircle(canvas, size, paint, fillPaint);
      case BoundingBoxStyle.arrow:
        _drawArrow(canvas, size, paint);
      case BoundingBoxStyle.point:
        _drawPoint(canvas, size, paint, fillPaint);
    }
  }

  void _drawRect(Canvas canvas, Size size, Paint paint, Paint fillPaint) {
    final rect = RRect.fromRectAndCorners(
      Rect.fromLTWH(0, 0, size.width, size.height),
      topLeft: Radius.circular(box.cornerRadius),
      topRight: Radius.circular(box.cornerRadius),
      bottomLeft: Radius.circular(box.cornerRadius),
      bottomRight: Radius.circular(box.cornerRadius),
    );

    canvas.drawRRect(rect, fillPaint);
    canvas.drawRRect(rect, paint);
  }

  void _drawCircle(Canvas canvas, Size size, Paint paint, Paint fillPaint) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final rx = size.width / 2;
    final ry = size.height / 2;

    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2),
      fillPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2),
      paint,
    );
  }

  void _drawArrow(Canvas canvas, Size size, Paint paint) {
    // Arrow from start to end (or default direction from box center).
    Offset start;
    Offset end;

    if (box.arrowStart != null && box.arrowEnd != null) {
      start = Offset(
        box.arrowStart!.x * canvasSize.width,
        box.arrowStart!.y * canvasSize.height,
      );
      end = Offset(
        box.arrowEnd!.x * canvasSize.width,
        box.arrowEnd!.y * canvasSize.height,
      );
    } else {
      final cx = size.width / 2;
      final cy = size.height / 2;
      final dir = box.arrowDirection ?? ArrowDirection.down;
      final arrowLen = math.min(size.width, size.height) * 0.3;

      start = Offset(cx, cy);
      end = switch (dir) {
        ArrowDirection.up    => Offset(cx, cy - arrowLen),
        ArrowDirection.down  => Offset(cx, cy + arrowLen),
        ArrowDirection.left  => Offset(cx - arrowLen, cy),
        ArrowDirection.right => Offset(cx + arrowLen, cy),
      };
    }

    // Draw line.
    canvas.drawLine(start, end, paint);

    // Draw arrowhead.
    final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
    const headLen = 12.0;
    const headAngle = math.pi / 6;

    canvas.drawLine(
      end,
      Offset(
        end.dx - headLen * math.cos(angle - headAngle),
        end.dy - headLen * math.sin(angle - headAngle),
      ),
      paint,
    );
    canvas.drawLine(
      end,
      Offset(
        end.dx - headLen * math.cos(angle + headAngle),
        end.dy - headLen * math.sin(angle + headAngle),
      ),
      paint,
    );
  }

  void _drawPoint(Canvas canvas, Size size, Paint paint, Paint fillPaint) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = box.pointRadius ?? 8.0;

    // Outer ring.
    canvas.drawCircle(Offset(cx, cy), radius + 4, paint);
    // Filled center.
    canvas.drawCircle(Offset(cx, cy), radius, fillPaint);
    // Inner bright dot.
    final innerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawCircle(Offset(cx, cy), radius * 0.35, innerPaint);
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter old) {
    return old.box != box || old.color != color || old.canvasSize != canvasSize;
  }
}
