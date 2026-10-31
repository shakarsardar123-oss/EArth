/// subtitle_overlay_state.dart
/// AURA Assistant – Step 27: Live Kurdish Subtitle Overlay
///
/// Domain model for the overall subtitle overlay state.
/// FAIL-CLOSED: unknown → hidden, error → hidden.
/// Kurdish Sorani RTL-first.
library;

import 'package:meta/meta.dart';
import 'subtitle_entry.dart';

/// Whether the overlay is visible.
enum OverlayVisibility {
  visible,
  hidden,
  denied,
  unknown,
  ;

  static OverlayVisibility fromName(String name) =>
      OverlayVisibility.values.firstWhere(
        (e) => e.name == name,
        orElse: () => OverlayVisibility.unknown,
      );

  bool get isVisible => this == visible;
  bool get isBlocking => this == denied || this == unknown;
}

/// Immutable subtitle overlay state.
@immutable
class SubtitleOverlayState {
  /// Whether the overlay is visible.
  final OverlayVisibility visibility;

  /// Current active subtitle entries.
  final List<SubtitleEntry> entries;

  /// Maximum number of entries displayed at once.
  final int maxVisibleEntries;

  /// Current text direction — Kurdish Sorani: RTL.
  final SubtitleDirection textDirection;

  /// Locale — Kurdish Sorani RTL first.
  final String locale;

  /// Font size in logical pixels.
  final double fontSize;

  /// Background opacity (0.0-1.0).
  final double backgroundOpacity;

  /// Whether low-confidence subtitles are shown.
  final bool showLowConfidence;

  const SubtitleOverlayState({
    this.visibility = OverlayVisibility.hidden,
    this.entries = const [],
    this.maxVisibleEntries = 3,
    this.textDirection = SubtitleDirection.rtl,
    this.locale = 'ku',
    this.fontSize = 18.0,
    this.backgroundOpacity = 0.7,
    this.showLowConfidence = false,
  });

  /// FAIL-CLOSED: denied/unknown state — overlay hidden.
  factory SubtitleOverlayState.denied() =>
      const SubtitleOverlayState(
        visibility: OverlayVisibility.denied,
        entries: [],
      );

  /// FAIL-CLOSED: unknown → hidden.
  factory SubtitleOverlayState.unknown() =>
      const SubtitleOverlayState(
        visibility: OverlayVisibility.unknown,
        entries: [],
      );

  /// Whether the overlay is currently usable.
  bool get isUsable => visibility.isVisible;

  /// Visible entries (active or fading, and not low-confidence if filtered).
  List<SubtitleEntry> get visibleEntries =>
      entries.where((e) => e.isVisible && (showLowConfidence || !e.isLowConfidence))
          .take(maxVisibleEntries)
          .toList();

  SubtitleOverlayState copyWith({
    OverlayVisibility? visibility,
    List<SubtitleEntry>? entries,
    int? maxVisibleEntries,
    double? fontSize,
    double? backgroundOpacity,
    bool? showLowConfidence,
  }) =>
      SubtitleOverlayState(
        visibility: visibility ?? this.visibility,
        entries: entries ?? this.entries,
        maxVisibleEntries: maxVisibleEntries ?? this.maxVisibleEntries,
        textDirection: textDirection,
        locale: locale,
        fontSize: fontSize ?? this.fontSize,
        backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
        showLowConfidence: showLowConfidence ?? this.showLowConfidence,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubtitleOverlayState && visibility == other.visibility;

  @override
  int get hashCode => visibility.hashCode;

  @override
  String toString() =>
      'SubtitleOverlayState(visibility: $visibility, '
      'entries: ${entries.length}, dir: $textDirection)';
}
