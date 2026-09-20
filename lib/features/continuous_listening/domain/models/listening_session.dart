/// listening_session.dart
/// AURA Assistant – Step 27: Continuous Listening & Smart Segmentation
///
/// Domain model for a continuous listening session.
/// FAIL-CLOSED: unknown → inactive, error → inactive,
///              unavailable → inactive, unauthorized → inactive.
/// Kurdish Sorani RTL-first: STT='ckb_IQ'.
library;

import 'package:meta/meta.dart';

/// State of the continuous listening session.
enum ListeningState {
  active,
  paused,
  inactive,
  error,
  denied,
  unknown,
  ;

  static ListeningState fromName(String name) =>
      ListeningState.values.firstWhere(
        (e) => e.name == name,
        orElse: () => ListeningState.unknown,
      );

  /// FAIL-CLOSED: only active is usable.
  bool get isActive => this == active;

  /// Whether the state blocks listening.
  bool get isBlocking =>
      this == inactive || this == error || this == denied || this == unknown;
}

/// Audio segmentation mode.
enum SegmentationMode {
  voiceActivityDetection,
  silenceThreshold,
  speakerChange,
  sentenceBoundary,
  hybrid,
  unknown,
  ;

  static SegmentationMode fromName(String name) =>
      SegmentationMode.values.firstWhere(
        (e) => e.name == name,
        orElse: () => SegmentationMode.unknown,
      );

  bool get isUsable => this != unknown;
}

/// Immutable listening session.
@immutable
class ListeningSession {
  /// Unique session identifier.
  final String sessionId;

  /// Current state.
  final ListeningState state;

  /// Segmentation mode.
  final SegmentationMode segmentationMode;

  /// STT language code — Kurdish Sorani: 'ckb_IQ'.
  final String sttLanguage;

  /// Locale — Kurdish Sorani RTL first.
  final String locale;

  /// Silence threshold in milliseconds.
  final int silenceThresholdMs;

  /// Maximum segment duration in milliseconds.
  final int maxSegmentDurationMs;

  /// Whether VAD (voice activity detection) is enabled.
  final bool vadEnabled;

  /// Number of segments produced so far.
  final int segmentCount;

  /// Session start time.
  final DateTime startedAt;

  /// Last activity timestamp.
  final DateTime? lastActivityAt;

  const ListeningSession({
    required this.sessionId,
    this.state = ListeningState.inactive,
    this.segmentationMode = SegmentationMode.hybrid,
    this.sttLanguage = 'ckb_IQ',
    this.locale = 'ku',
    this.silenceThresholdMs = 800,
    this.maxSegmentDurationMs = 30000,
    this.vadEnabled = true,
    this.segmentCount = 0,
    required this.startedAt,
    this.lastActivityAt,
  });

  /// FAIL-CLOSED: factory for unknown/denied sessions.
  factory ListeningSession.denied({
    required String sessionId,
    String? reason,
  }) =>
      ListeningSession(
        sessionId: sessionId,
        state: ListeningState.denied,
        startedAt: DateTime.now(),
        locale: 'ku',
      );

  /// FAIL-CLOSED: unknown state is never active.
  bool get isUsable => state.isActive;

  ListeningSession copyWith({
    ListeningState? state,
    int? segmentCount,
    DateTime? lastActivityAt,
  }) =>
      ListeningSession(
        sessionId: sessionId,
        state: state ?? this.state,
        segmentationMode: segmentationMode,
        sttLanguage: sttLanguage,
        locale: locale,
        silenceThresholdMs: silenceThresholdMs,
        maxSegmentDurationMs: maxSegmentDurationMs,
        vadEnabled: vadEnabled,
        segmentCount: segmentCount ?? this.segmentCount,
        startedAt: startedAt,
        lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListeningSession && sessionId == other.sessionId;

  @override
  int get hashCode => sessionId.hashCode;

  @override
  String toString() =>
      'ListeningSession(id: $sessionId, state: $state, '
      'mode: $segmentationMode, segments: $segmentCount)';
}
