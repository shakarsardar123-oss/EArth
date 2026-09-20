import 'bounding_box.dart';

/// Represents a detected target (object, text region, person, etc.)
/// within an image, with location information.
///
/// Used by the AI vision analysis to report what it found and where.
class VisionTarget {
  const VisionTarget({
    required this.type,
    required this.label,
    this.boundingBox,
    this.confidence,
    this.description,
    this.attributes = const {},
    this.id,
  });

  /// Type of target (e.g. 'object', 'text', 'person', 'scene_element').
  final VisionTargetType type;

  /// Short label / name for this target.
  final String label;

  /// Location of the target in the image (normalized 0–1 coords).
  final BoundingBox? boundingBox;

  /// Detection confidence (0–1), if available.
  final double? confidence;

  /// Detailed description of the target.
  final String? description;

  /// Additional attributes (e.g. {'color': 'red', 'size': 'large'}). 
  final Map<String, dynamic> attributes;

  /// Unique identifier.
  final String? id;

  /// Convert to JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'type': type.name,
        'label': label,
        'bounding_box': boundingBox?.toJson(),
        'confidence': confidence,
        'description': description,
        'attributes': attributes,
        'id': id,
      };

  /// Create from JSON map.
  factory VisionTarget.fromJson(Map<String, dynamic> json) => VisionTarget(
        type: VisionTargetType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => VisionTargetType.object,
        ),
        label: json['label'] as String,
        boundingBox: json['bounding_box'] != null
            ? BoundingBox.fromJson(json['bounding_box'] as Map<String, dynamic>)
            : null,
        confidence: json['confidence'] != null
            ? (json['confidence'] as num).toDouble()
            : null,
        description: json['description'] as String?,
        attributes: json['attributes'] != null
            ? Map<String, dynamic>.from(json['attributes'] as Map)
            : const {},
        id: json['id'] as String?,
      );

  @override
  String toString() =>
      'VisionTarget($type: $label, confidence: $confidence, box: $boundingBox)';
}

/// Categories of vision targets.
enum VisionTargetType {
  /// Generic object.
  object,

  /// Detected text / OCR region.
  text,

  /// Person / human figure.
  person,

  /// Scene element (building, tree, sky, etc.).
  sceneElement,

  /// Animal.
  animal,

  /// Vehicle.
  vehicle,

  /// Food item.
  food,

  /// Pose landmark (for pose extension).
  poseLandmark,

  /// Custom / other.
  other,
}
