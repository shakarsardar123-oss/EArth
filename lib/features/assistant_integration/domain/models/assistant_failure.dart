/// Failures that can occur during the assistant integration lifecycle.
///
/// Follows the project convention: phase enum + factory constructors.
/// The [AssistantPhase] identifies *when* the failure happened,
/// and the [message] / [cause] carry diagnostic detail.
library;

import 'package:aura_assistant/core/errors/result.dart';

/// Phase of the assistant integration where a failure occurred.
enum AssistantPhase {
  /// Checking whether the platform supports assistant role.
  detection,

  /// Requesting default-assistant status from the platform.
  statusCheck,

  /// Opening the Android system assistant-settings screen.
  openSettings,

  /// Receiving and parsing an incoming assistant invocation.
  invocation,

  /// Routing the invocation into the voice/agent pipeline.
  pipelineRouting,

  /// Voice invocation processing.
  voiceInvocation,
}

/// Failure type for assistant integration operations.
///
/// Each failure carries a [phase] that identifies the lifecycle step
/// where the error happened, plus a human-readable [message] and an
/// optional underlying [cause].
class AssistantFailure {
  final AssistantPhase phase;
  final String message;
  final Object? cause;

  const AssistantFailure._({
    required this.phase,
    required this.message,
    this.cause,
  });

  // ── Factory constructors ─────────────────────────────────────────────

  /// Platform does not support the assistant role.
  factory AssistantFailure.unsupportedPlatform({int? apiLevel}) {
    return AssistantFailure._(
      phase: AssistantPhase.detection,
      message: apiLevel != null
          ? 'Assistant role not supported (API $apiLevel).'
          : 'Assistant role not supported on this platform.',
    );
  }

  /// Status-check call to the platform channel threw an error.
  factory AssistantFailure.statusCheckFailed(Object cause) {
    return AssistantFailure._(
      phase: AssistantPhase.statusCheck,
      message: 'Failed to check default-assistant status.',
      cause: cause,
    );
  }

  /// Opening the system assistant-settings activity failed.
  factory AssistantFailure.openSettingsFailed(Object cause) {
    return AssistantFailure._(
      phase: AssistantPhase.openSettings,
      message: 'Could not open Android assistant settings.',
      cause: cause,
    );
  }

  /// Parsing the incoming invocation intent failed.
  factory AssistantFailure.invocationParseFailed(Object cause) {
    return AssistantFailure._(
      phase: AssistantPhase.invocation,
      message: 'Failed to parse assistant invocation data.',
      cause: cause,
    );
  }

  /// Routing the invocation into the agent/voice pipeline failed.
  factory AssistantFailure.pipelineRoutingFailed(Object cause) {
    return AssistantFailure._(
      phase: AssistantPhase.pipelineRouting,
      message: 'Failed to route assistant invocation to pipeline.',
      cause: cause,
    );
  }

  /// Voice invocation processing failed.
  factory AssistantFailure.voiceInvocationFailed(Object cause) {
    return AssistantFailure._(
      phase: AssistantPhase.voiceInvocation,
      message: 'Voice invocation processing failed.',
      cause: cause,
    );
  }

  // ── Convenience ──────────────────────────────────────────────────────

  /// Wrap this failure as a [Result.Failure].
  Result<T, AssistantFailure> asFailure<T>() => Result.failure(this);

  @override
  String toString() =>
      'AssistantFailure(phase: $phase, message: $message, cause: $cause)';
}
