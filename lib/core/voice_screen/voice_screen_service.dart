/// Abstract interface for the VoiceScreen orchestration service.
///
/// Coordinates VoiceService + ScreenCaptureService +
/// ScreenUnderstandingService + ScreenSearchService +
/// FloatingAuraService into one pipeline:
/// Voice → Capture → Understand → Search → CombineContext → VoiceResponse.
library;

import 'package:aura_assistant/core/errors/result.dart';
import 'package:aura_assistant/core/voice_screen/voice_screen_failure.dart';
import 'package:aura_assistant/core/voice_screen/voice_screen_state.dart';

/// Search query model used by the search service.
/// Re-exported for convenience; defined in the search module.
class VoiceScreenSearchQuery {
  const VoiceScreenSearchQuery({
    this.targetType,
    this.query,
    this.minConfidence,
    this.maxResults,
  });

  final String? targetType;
  final String? query;
  final double? minConfidence;
  final int? maxResults;
}

/// Abstract service that orchestrates the full voice-screen pipeline.
abstract class VoiceScreenService {
  /// Start a new voice-screen interaction.
  ///
  /// If [query] is provided, the search stage will use it; otherwise
  /// a default query is constructed from the recognized voice text
  /// and screen content.
  ///
  /// Returns a [Result] indicating whether the interaction was
  /// successfully started or failed (e.g. concurrent conflict,
  /// permission denied, security violation).
  Future<Result<void, VoiceScreenFailure>> startInteraction([
    VoiceScreenSearchQuery? query,
  ]);

  /// Process recognized text from the voice service.
  ///
  /// Called internally when the voice service emits recognized text.
  /// Can also be called externally for testing or manual input.
  Future<Result<void, VoiceScreenFailure>> processRecognizedText(
    String text,
  );

  /// Cancel the currently active interaction, if any.
  ///
  /// Returns [Result.success] if cancellation succeeded or there
  /// was nothing to cancel; [Result.failure] if cancellation itself
  /// encountered an error.
  Future<Result<void, VoiceScreenFailure>> cancelCurrentInteraction();

  /// The current state of the orchestrator.
  VoiceScreenState get state;

  /// A broadcast stream of state changes.
  Stream<VoiceScreenState> get stateStream;

  /// Release all resources held by this service.
  void dispose();
}
