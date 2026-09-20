/// screen_target.dart
/// AURA Assistant – Step 27: Universal Screen Target Detection & Correction
///
/// Domain model for a detected screen target (UI element).
/// FAIL-CLOSED: unknown → invalid, unverified → invalid.
library;

import 'package:meta/meta.dart';

/// Type of detected screen target.
enum ScreenTargetType {
  button,
  input,
  toggle,
  slider,
  icon,
  text,
  image,
  link,
  card,
  dialog,
  unknown,
  ;

  static ScreenTargetType fromName(String name) =>
      ScreenTargetType.values.firstWhere(
        (e) => e.name == name,
        orElse: () => ScreenTargetType.unknown,
      );

  bool get isActionable =>
      this == button ||
      this == input ||
      this == toggle ||
      this == slider ||
      this == link;
  bool get isUnknown => this == unknown;
}

/// Confidence of the detection.
enum DetectionConfidence {
  high,
  medium,
  low,
  unknown,
  ;

  bool get isUsable => this == high || this == medium;
  bool get isLow => this == low || this == unknown;
}

/// Immutable detected screen target.
@immutable
class ScreenTarget {
  /// Unique target identifier.
  final String targetId;

  /// Target type.
  final ScreenTargetType type;

  /// Bounding rectangle: {left, top, width, height}.
  final Map<String, double> bounds;

  /// Detection confidence.
  final DetectionConfidence confidence;

  /// Semantic label (accessibility label or OCR text).
  final String label;

  /// Whether the target has been verified (accessibility tree or second pass).
  final bool verified;

  /// Locale — Kurdish Sorani RTL first.
  final String locale;

  /// Screen capture timestamp.
  final DateTime detectedAt;

  /// Parent screen identifier.
  final String screenId;

  const ScreenTarget({
    required this.targetId,
    this.type = ScreenTargetType.unknown,
    this.bounds = const {},
    this.confidence = DetectionConfidence.unknown,
    this.label = '',
    this.verified = false,
    this.locale = 'ku',
    required this.detectedAt,
    this.screenId = '',
  });

  /// FAIL-CLOSED: factory for invalid/unknown targets.
  factory ScreenTarget.invalid({
    required String targetId,
    String? reason,
  }) =>
      ScreenTarget(
        targetId: targetId,
        type: ScreenTargetType.unknown,
        confidence: DetectionConfidence.unknown,
        verified: false,
        detectedAt: DateTime.now(),
        locale: 'ku',
      );

  /// FAIL-CLOSED: unverified/unknown targets are not actionable.
  bool get isActionable =>
      type.isActionable && verified && confidence.isUsable && label.isNotEmpty;

  /// Whether the target is usable.
  bool get isUsable => !type.isUnknown && verified;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScreenTarget && targetId == other.targetId;

  @override
  int get hashCode => targetId.hashCode;

  @override
  String toString() =>
      'ScreenTarget(id: $targetId, type: $type, '
      'conf: $confidence, verified: $verified)';
}
