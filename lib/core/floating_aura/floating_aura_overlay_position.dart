/// Immutable position model for the floating AURA overlay button.
///
/// Represents the X/Y offset (in dp) of the floating overlay relative
/// to the top-left corner of the screen. Used for position persistence
/// via [StorageService].
library;

import 'package:meta/meta.dart';

import 'floating_aura_constants.dart';

/// Screen position of the floating overlay button.
///
/// Values are in dp from the top-left corner of the display.
/// This class is [@immutable] — use [copyWith] to create modified
/// instances.
@immutable
class FloatingAuraOverlayPosition {
  const FloatingAuraOverlayPosition({
    required this.x,
    required this.y,
  });

  /// Horizontal offset from the left edge of the screen (dp).
  final double x;

  /// Vertical offset from the top edge of the screen (dp).
  final double y;

  /// Position with default screen coordinates.
  static FloatingAuraOverlayPosition get defaults =>
      const FloatingAuraOverlayPosition(
        x: FloatingAuraDefaults.defaultPositionX,
        y: FloatingAuraDefaults.defaultPositionY,
      );

  /// Creates a copy of this position with optionally updated fields.
  FloatingAuraOverlayPosition copyWith({
    double? x,
    double? y,
  }) {
    return FloatingAuraOverlayPosition(
      x: x ?? this.x,
      y: y ?? this.y,
    );
  }

  /// Converts the position to a map for platform-channel transfer.
  Map<String, dynamic> toMap() => {
        'x': x,
        'y': y,
      };

  /// Creates a position from a platform-channel map.
  factory FloatingAuraOverlayPosition.fromMap(Map<dynamic, dynamic> map) {
    return FloatingAuraOverlayPosition(
      x: (map['x'] as num?)?.toDouble() ??
          FloatingAuraDefaults.defaultPositionX,
      y: (map['y'] as num?)?.toDouble() ??
          FloatingAuraDefaults.defaultPositionY,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FloatingAuraOverlayPosition &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'FloatingAuraOverlayPosition(x: $x, y: $y)';
}
