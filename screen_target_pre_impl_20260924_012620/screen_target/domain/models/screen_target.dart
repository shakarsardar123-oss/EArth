/// Step 27 — Screen Target Model
///
/// Represents a detected target on the device screen.
///
/// AUDIT FIX — Bug #7:
///   Added copyWith method with all fields as optional parameters.
///   The original model had no copyWith, making immutable updates
///   impossible without manual field copying.

class ScreenTarget {
  final String targetId;
  final String type;
  final Map<String, dynamic>? bounds;
  final double confidence;
  final String? label;
  final bool verified;
  final String locale;
  final DateTime detectedAt;
  final String? screenId;

  const ScreenTarget({
    required this.targetId,
    required this.type,
    this.bounds,
    this.confidence = 0.0,
    this.label,
    this.verified = false,
    this.locale = 'ku',
    required this.detectedAt,
    this.screenId,
  });

  /// Create a copy of this ScreenTarget with optionally overridden fields.
  ScreenTarget copyWith({
    String? targetId,
    String? type,
    Map<String, dynamic>? bounds,
    double? confidence,
    String? label,
    bool? verified,
    String? locale,
    DateTime? detectedAt,
    String? screenId,
  }) {
    return ScreenTarget(
      targetId: targetId ?? this.targetId,
      type: type ?? this.type,
      bounds: bounds ?? this.bounds,
      confidence: confidence ?? this.confidence,
      label: label ?? this.label,
      verified: verified ?? this.verified,
      locale: locale ?? this.locale,
      detectedAt: detectedAt ?? this.detectedAt,
      screenId: screenId ?? this.screenId,
    );
  }

  /// Whether this target has sufficient confidence for action.
  /// FAIL-CLOSED: confidence below threshold → not actionable.
  bool get isActionable => confidence >= 0.7 && verified;

  @override
  String toString() =>
      'ScreenTarget($targetId, type=$type, confidence=$confidence, verified=$verified, locale=$locale)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ScreenTarget &&
        other.targetId == targetId &&
        other.type == type &&
        other.confidence == confidence &&
        other.verified == verified &&
        other.locale == locale;
  }

  @override
  int get hashCode =>
      targetId.hashCode ^
      type.hashCode ^
      confidence.hashCode ^
      verified.hashCode ^
      locale.hashCode;
}
