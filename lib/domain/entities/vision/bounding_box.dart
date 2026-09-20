/// Normalized bounding box (0.0–1.0) relative to image dimensions.
///
/// Used for object localization and overlay rendering.
class BoundingBox {
  const BoundingBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  this.label,
    this.confidence,
  this.color,
  this.id,
  this.style = BoundingBoxStyle.rect,
  this.arrowDirection,
  this.arrowStart,
  this.arrowEnd,
  this.pointRadius,
  this.labelPosition = LabelPosition.topLeft,
  this.showLabel = true,
  this.showConfidence = false,
  this.lineWidth = 2.0,
  this.cornerRadius = 4.0,
  this.fillOpacity = 0.08,
    this.description,
  });

  /// X position (0–1, left edge).
  final double x;

  /// Y position (0–1, top edge).
  final double y;

  /// Width (0–1).
  final double width;

  /// Height (0–1).
  final double height;

  /// Optional label (object name / text content).
  final String? label;

  /// Optional confidence score (0–1).
  final double? confidence;

  /// Optional color override for the overlay.
  final int? color;

  /// Unique identifier for this target.
  final String? id;

  /// Visual style of the overlay.
  final BoundingBoxStyle style;

  /// Arrow direction (only for BoundingBoxStyle.arrow).
  final ArrowDirection? arrowDirection;

  /// Arrow start point in normalized coords (for custom arrows).
  final ArrowPoint? arrowStart;

  /// Arrow end point in normalized coords (for custom arrows).
  final ArrowPoint? arrowEnd;

  /// Point radius in logical pixels (only for BoundingBoxStyle.point).
  final double? pointRadius;

  /// Where the label is placed relative to the box.
  final LabelPosition labelPosition;

  /// Whether to show the label text.
  final bool showLabel;

  /// Whether to show the confidence percentage.
  final bool showConfidence;

  /// Line width for rect / circle / arrow drawing.
  final double lineWidth;

  /// Corner radius for rect style.
  final double cornerRadius;

  /// Fill opacity behind the shape (0 = transparent, 1 = solid).
  final double fillOpacity;

  /// Optional description of the target.
  final String? description;

  /// Center X of the box.
  double get cx => x + width / 2;

  /// Center Y of the box.
  double get cy => y + height / 2;

  /// Right edge.
  double get right => x + width;

  /// Bottom edge.
  double get bottom => y + height;

  /// Area (0–1).
  double get area => width * height;

  /// Convert to JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'label': label,
        'confidence': confidence,
        'color': color,
        'id': id,
        'style': style.name,
        'arrow_direction': arrowDirection?.name,
        'arrow_start': arrowStart?.toJson(),
        'arrow_end': arrowEnd?.toJson(),
        'point_radius': pointRadius,
        'label_position': labelPosition.name,
        'show_label': showLabel,
        'show_confidence': showConfidence,
        'description': description,
      };

  /// Create from JSON map.
  factory BoundingBox.fromJson(Map<String, dynamic> json) => BoundingBox(
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        width: (json['width'] as num).toDouble(),
        height: (json['height'] as num).toDouble(),
        label: json['label'] as String?,
        confidence: json['confidence'] != null
            ? (json['confidence'] as num).toDouble()
            : null,
        color: json['color'] as int?,
        id: json['id'] as String?,
        style: BoundingBoxStyle.values.firstWhere(
          (e) => e.name == json['style'],
          orElse: () => BoundingBoxStyle.rect,
        ),
        arrowDirection: json['arrow_direction'] != null
            ? ArrowDirection.values.firstWhere(
                (e) => e.name == json['arrow_direction'],
                orElse: () => ArrowDirection.down,
              )
            : null,
        arrowStart: json['arrow_start'] != null
            ? ArrowPoint.fromJson(json['arrow_start'] as Map<String, dynamic>)
            : null,
        arrowEnd: json['arrow_end'] != null
            ? ArrowPoint.fromJson(json['arrow_end'] as Map<String, dynamic>)
            : null,
        pointRadius: json['point_radius'] != null
            ? (json['point_radius'] as num).toDouble()
            : null,
        labelPosition: LabelPosition.values.firstWhere(
          (e) => e.name == (json['label_position'] as String?),
          orElse: () => LabelPosition.topLeft,
        ),
        showLabel: json['show_label'] as bool? ?? true,
        showConfidence: json['show_confidence'] as bool? ?? false,
        description: json['description'] as String?,
      );

  @override
  String toString() =>
      'BoundingBox($label: x=$x, y=$y, w=$width, h=$height, style=${style.name})';
}

/// Visual style of the bounding box overlay.
enum BoundingBoxStyle {
  /// Rectangle outline.
  rect,

  /// Circle/ellipse outline.
  circle,

  /// Arrow pointing to target.
  arrow,

  /// Single point dot.
  point,
}

/// Arrow direction for arrow-style overlays.
enum ArrowDirection {
  up,
  down,
  left,
  right,
}

/// A point in normalized coordinates, used for arrow endpoints.
class ArrowPoint {
  const ArrowPoint({required this.x, required this.y});

  final double x;
  final double y;

  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  factory ArrowPoint.fromJson(Map<String, dynamic> json) => ArrowPoint(
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
      );
}

/// Label position relative to the bounding box.
enum LabelPosition {
  topLeft,
  topCenter,
  topRight,
  bottomLeft,
  bottomCenter,
  bottomRight,
  center,
}
