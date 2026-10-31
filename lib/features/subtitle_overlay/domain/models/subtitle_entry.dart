/// subtitle_entry.dart
/// AURA Assistant – Step 27: Live Kurdish Subtitle Overlay
///
/// Domain model for a single subtitle entry.
/// FAIL-CLOSED: unknown → invalid, empty text → invalid.
/// Kurdish Sorani RTL-first: locale='ku'.
library;

import 'package:meta/meta.dart';

/// Status of a subtitle entry.
enum SubtitleStatus {
  active,
  fading,
  expired,
  denied,
  unknown,
  ;

  static SubtitleStatus fromName(String name) =>
      SubtitleStatus.values.firstWhere(
        (e) => e.name == name,
        orElse: () => SubtitleStatus.unknown,
      );

  bool get isVisible => this == active || this == fading;
  bool get isBlocking => this == denied || this == unknown;
}

/// Text direction for subtitle rendering.
enum SubtitleDirection {
  rtl,
  ltr,
  auto,
  unknown,
  ;

  static SubtitleDirection fromName(String name) =>
      SubtitleDirection.values.firstWhere(
        (e) => e.name == name,
        orElse: () => SubtitleDirection.unknown,
      );

  /// FAIL-CLOSED: unknown defaults to RTL for Kurdish.
  SubtitleDirection get resolved =>
      this == unknown ? SubtitleDirection.rtl : this;
}

/// Immutable subtitle entry for overlay rendering.
@immutable
class SubtitleEntry {
  /// Unique subtitle identifier.
  final String subtitleId;

  /// Display text.
  final String text;

  /// Time when the subtitle first appears.
  final DateTime startTime;

  /// Duration the subtitle is visible, in milliseconds.
  final int displayDurationMs;

  /// STT confidence (0.0-1.0).
  final double confidence;

  /// Text direction — RTL for Kurdish Sorani.
  final SubtitleDirection direction;

  /// Status.
  final SubtitleStatus status;

  /// Locale — Kurdish Sorani RTL first.
  final String locale;

  /// Source segment identifier (from continuous listening).
  final String sourceSegmentId;

  /// Font size override (null = default).
  final int? fontSizeOverride;

  /// Position offset from bottom in logical pixels.
  final double bottomOffset;

  const SubtitleEntry({
    required this.subtitleId,
    required this.text,
    required this.startTime,
    this.displayDurationMs = 4000,
    this.confidence = 0.0,
    this.direction = SubtitleDirection.rtl,
    this.status = SubtitleStatus.active,
    this.locale = 'ku',
    this.sourceSegmentId = '',
    this.fontSizeOverride,
    this.bottomOffset = 64.0,
  });

  /// FAIL-CLOSED: factory for denied/invalid subtitles.
  factory SubtitleEntry.denied({
    required String subtitleId,
    String? reason,
  }) =>
      SubtitleEntry(
        subtitleId: subtitleId,
        text: '',
        startTime: DateTime.now(),
        status: SubtitleStatus.denied,
        locale: 'ku',
      );

  /// FAIL-CLOSED: unknown state is never visible.
  bool get isVisible => status.isVisible && text.isNotEmpty;

  /// Whether the entry has usable content.
  bool get isUsable => text.isNotEmpty && !status.isBlocking;

  /// Whether the confidence is too low for display.
  bool get isLowConfidence => confidence < 0.4 && text.isNotEmpty;

  SubtitleEntry copyWith({
    SubtitleStatus? status,
    int? displayDurationMs,
    double? confidence,
  }) =>
      SubtitleEntry(
        subtitleId: subtitleId,
        text: text,
        startTime: startTime,
        displayDurationMs: displayDurationMs ?? this.displayDurationMs,
        confidence: confidence ?? this.confidence,
        direction: direction,
        status: status ?? this.status,
        locale: locale,
        sourceSegmentId: sourceSegmentId,
        fontSizeOverride: fontSizeOverride,
        bottomOffset: bottomOffset,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubtitleEntry && subtitleId == other.subtitleId;

  @override
  int get hashCode => subtitleId.hashCode;

  @override
  String toString() =>
      'SubtitleEntry(id: $subtitleId, text: "$text", '
      'status: $status, dir: $direction)';
}
