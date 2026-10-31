/// audio_segment.dart
/// AURA Assistant – Step 27: Continuous Listening & Smart Segmentation
///
/// Domain model for a segmented audio chunk.
/// FAIL-CLOSED: empty segment → invalid, unknown language → invalid.
library;

import 'package:meta/meta.dart';

/// Result of processing a segment.
enum SegmentProcessingStatus {
  transcribed,
  pending,
  failed,
  denied,
  unknown,
  ;

  static SegmentProcessingStatus fromName(String name) =>
      SegmentProcessingStatus.values.firstWhere(
        (e) => e.name == name,
        orElse: () => SegmentProcessingStatus.unknown,
      );

  bool get isTranscribed => this == transcribed;
  bool get isFailed =>
      this == failed || this == denied || this == unknown;
}

/// Immutable audio segment from continuous listening.
@immutable
class AudioSegment {
  /// Unique segment identifier.
  final String segmentId;

  /// Parent session identifier.
  final String sessionId;

  /// Segment index in the session (0-based).
  final int index;

  /// Start time of the segment.
  final DateTime startTime;

  /// Duration in milliseconds.
  final int durationMs;

  /// Transcription text (if transcribed).
  final String transcription;

  /// STT confidence (0.0-1.0).
  final double confidence;

  /// STT language code — Kurdish Sorani: 'ckb_IQ'.
  final String sttLanguage;

  /// Processing status.
  final SegmentProcessingStatus status;

  /// Locale — Kurdish Sorani RTL first.
  final String locale;

  /// Whether the segment contains speech (VAD result).
  final bool hasSpeech;

  const AudioSegment({
    required this.segmentId,
    required this.sessionId,
    required this.index,
    required this.startTime,
    this.durationMs = 0,
    this.transcription = '',
    this.confidence = 0.0,
    this.sttLanguage = 'ckb_IQ',
    this.status = SegmentProcessingStatus.pending,
    this.locale = 'ku',
    this.hasSpeech = false,
  });

  /// FAIL-CLOSED: factory for invalid/unknown segments.
  factory AudioSegment.invalid({
    required String segmentId,
    required String sessionId,
  }) =>
      AudioSegment(
        segmentId: segmentId,
        sessionId: sessionId,
        index: -1,
        startTime: DateTime.now(),
        status: SegmentProcessingStatus.unknown,
        locale: 'ku',
      );

  /// FAIL-CLOSED: low confidence segments should be denied/asked.
  bool get isLowConfidence => confidence < 0.5 && hasSpeech;

  /// Whether the segment has usable content.
  bool get isUsable =>
      hasSpeech && transcription.isNotEmpty && !status.isFailed;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioSegment && segmentId == other.segmentId;

  @override
  int get hashCode => segmentId.hashCode;

  @override
  String toString() =>
      'AudioSegment(id: $segmentId, idx: $index, '
      'status: $status, conf: $confidence)';
}
