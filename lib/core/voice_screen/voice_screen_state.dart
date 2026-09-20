/// State model for the [VoiceScreenEngine] orchestrator.
library;

import 'package:aura_assistant/core/voice_screen/voice_screen_failure.dart';

/// Status of the voice-screen interaction pipeline.
enum VoiceScreenStatus {
  /// No active interaction.
  idle,

  /// Microphone is active and listening.
  listening,

  /// Voice recognized text is being transcribed / finalized.
  transcribing,

  /// Engine is deciding which pipeline stages to execute.
  deciding,

  /// Screen capture is in progress.
  capturingScreen,

  /// Captured frame is being analyzed by screen-understanding.
  understandingScreen,

  /// Screen search is in progress.
  searchingScreen,

  /// Search results and voice text are being combined into context.
  combiningContext,

  /// Interaction completed successfully.
  completed,

  /// Interaction was cancelled by the user or engine.
  cancelled,

  /// A required permission was denied.
  permissionDenied,

  /// An error occurred in the pipeline.
  error;

  /// Whether the pipeline is actively processing (not idle, completed,
  /// cancelled, permissionDenied, or error).
  bool get isActive =>
      this == listening ||
      this == transcribing ||
      this == deciding ||
      this == capturingScreen ||
      this == understandingScreen ||
      this == searchingScreen ||
      this == combiningContext;
}

/// Sentinel object for [VoiceScreenState.copyWith] nullable fields.
class _Sentinel {
  const _Sentinel();
}

const _sentinel = _Sentinel();

/// Combined context produced by a successful voice-screen interaction.
///
/// Contains both the recognized voice text and the search results
/// (if any) from the screen content.
class VoiceScreenContext {
  const VoiceScreenContext({
    required this.recognizedText,
    this.searchResults,
    this.screenRepresentation,
    this.capturedFrameTimestamp,
    this.generationId,
  });

  /// The text recognized from voice input.
  final String recognizedText;

  /// Search results from screen content (may be null if no search
  /// was performed or no results found).
  final dynamic searchResults;

  /// The screen representation from understanding (may be null).
  final dynamic screenRepresentation;

  /// Timestamp of the captured frame used for this context.
  final DateTime? capturedFrameTimestamp;

  /// Generation ID used for stale-result protection.
  final int? generationId;

  VoiceScreenContext copyWith({
    String? recognizedText,
    dynamic searchResults,
    dynamic screenRepresentation,
    DateTime? capturedFrameTimestamp,
    int? generationId,
  }) {
    return VoiceScreenContext(
      recognizedText: recognizedText ?? this.recognizedText,
      searchResults: searchResults ?? this.searchResults,
      screenRepresentation:
          screenRepresentation ?? this.screenRepresentation,
      capturedFrameTimestamp:
          capturedFrameTimestamp ?? this.capturedFrameTimestamp,
      generationId: generationId ?? this.generationId,
    );
  }
}

/// Immutable state snapshot for the VoiceScreenEngine.
///
/// Uses the _sentinel [copyWith] pattern for nullable fields
/// so that callers can explicitly set a field to null.
class VoiceScreenState {
  const VoiceScreenState({
    required this.status,
    this.recognizedText,
    this.context,
    this.failure,
    this.generationId = 0,
  });

  /// Current pipeline status.
  final VoiceScreenStatus status;

  /// Most recently recognized text (may accumulate across partial results).
  final String? recognizedText;

  /// Combined context from a completed interaction.
  final VoiceScreenContext? context;

  /// Failure information when [status] is [VoiceScreenStatus.error].
  final VoiceScreenFailure? failure;

  /// Monotonically increasing generation ID for stale-result protection.
  final int generationId;

  /// Whether an interaction is currently active.
  bool get isActive => status.isActive;

  static const VoiceScreenState initial = VoiceScreenState(
    status: VoiceScreenStatus.idle,
    generationId: 0,
  );

  VoiceScreenState copyWith({
    VoiceScreenStatus? status,
    Object? recognizedText = _sentinel,
    Object? context = _sentinel,
    Object? failure = _sentinel,
    int? generationId,
  }) {
    return VoiceScreenState(
      status: status ?? this.status,
      recognizedText: recognizedText == _sentinel
          ? this.recognizedText
          : recognizedText as String?,
      context: context == _sentinel
          ? this.context
          : context as VoiceScreenContext?,
      failure: failure == _sentinel
          ? this.failure
          : failure as VoiceScreenFailure?,
      generationId: generationId ?? this.generationId,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VoiceScreenState &&
        other.status == status &&
        other.recognizedText == recognizedText &&
        other.context == context &&
        other.failure == failure &&
        other.generationId == generationId;
  }

  @override
  int get hashCode =>
      Object.hash(status, recognizedText, context, failure, generationId);

  @override
  String toString() =>
      'VoiceScreenState(status: $status, recognizedText: $recognizedText, '
      'context: $context, failure: $failure, generationId: $generationId)';
}
