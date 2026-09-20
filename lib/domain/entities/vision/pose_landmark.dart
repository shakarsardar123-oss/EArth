/// A single pose landmark (keypoint) in normalized coordinates.
///
/// Foundation for future pose extension — not yet used by core vision
/// but defined now so the data model is stable.
class PoseLandmark {
  const PoseLandmark({
    required this.type,
    required this.x,
    required this.y,
    this.confidence,
    this.z,
    this.visibility,
  });

  /// Landmark type (e.g. 'nose', 'left_shoulder').
  final PoseLandmarkType type;

  /// X position (0–1, normalized to image width).
  final double x;

  /// Y position (0–1, normalized to image height).
  final double y;

  /// Detection confidence (0–1).
  final double? confidence;

  /// Z depth estimate (relative to hip), if available.
  final double? z;

  /// Visibility score (0–1), if available.
  final double? visibility;

  /// Convert to JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'type': type.name,
        'x': x,
        'y': y,
        'confidence': confidence,
        'z': z,
        'visibility': visibility,
      };

  /// Create from JSON map.
  factory PoseLandmark.fromJson(Map<String, dynamic> json) => PoseLandmark(
        type: PoseLandmarkType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => PoseLandmarkType.unknown,
        ),
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        confidence: json['confidence'] != null
            ? (json['confidence'] as num).toDouble()
            : null,
        z: json['z'] != null ? (json['z'] as num).toDouble() : null,
        visibility: json['visibility'] != null
            ? (json['visibility'] as num).toDouble()
            : null,
      );

  @override
  String toString() => 'PoseLandmark(${type.name}: x=$x, y=$y)';
}

/// Standard body pose landmark types (MediaPipe / COCO convention).
enum PoseLandmarkType {
  nose,
  leftEyeInner,
  leftEye,
  leftEyeOuter,
  rightEyeInner,
  rightEye,
  rightEyeOuter,
  leftEar,
  rightEar,
  mouthLeft,
  mouthRight,
  leftShoulder,
  rightShoulder,
  leftElbow,
  rightElbow,
  leftWrist,
  rightWrist,
  leftHip,
  rightHip,
  leftKnee,
  rightKnee,
  leftAnkle,
  rightAnkle,
  leftPinky,
  rightPinky,
  leftIndex,
  rightIndex,
  leftThumb,
  rightThumb,
  leftHeel,
  rightHeel,
  leftFootIndex,
  rightFootIndex,
  unknown,
}
