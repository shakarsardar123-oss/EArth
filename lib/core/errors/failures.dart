/// Base failure class for domain-layer error handling.
///
/// Following clean architecture conventions, [Failure] objects
/// are returned from repositories/services instead of throwing
/// exceptions, making error handling explicit and testable.
abstract class Failure {
  const Failure({required this.message, this.code});

  final String message;
  final String? code;

  @override
  String toString() => 'Failure(message: $message, code: $code)';
}

/// Failure arising from network / API operations.
class NetworkFailure extends Failure {
  const NetworkFailure({
    required super.message,
    super.code,
    this.statusCode,
  });

  final int? statusCode;
}

/// Failure arising from local storage operations.
class StorageFailure extends Failure {
  const StorageFailure({required super.message, super.code});
}

/// Failure arising from unexpected / unclassified errors.
class UnexpectedFailure extends Failure {
  const UnexpectedFailure({required super.message, super.code});
}

/// Failure arising from permission denial.
class PermissionFailure extends Failure {
  const PermissionFailure({
    required super.message,
    super.code,
    this.permission,
  });

  final String? permission;
}

/// Failure arising from AI provider errors.
class AIFailure extends Failure {
  const AIFailure({
    required super.message,
    super.code,
    this.statusCode,
    this.providerId,
  });

  final int? statusCode;
  final String? providerId;
}

/// Failure arising from voice (speech recognition / TTS) errors.
class VoiceFailure extends Failure {
  const VoiceFailure({required super.message, super.code});
}

/// Failure arising from screen capture (MediaProjection) errors.
///
/// Covers projection-request denial, VirtualDisplay setup failure,
/// frame-read errors, and capture-lifecycle issues.
class ScreenCaptureFailure extends Failure {
  const ScreenCaptureFailure({
    required super.message,
    super.code,
    this.phase,
  });

  /// The phase during which the failure occurred.
  final ScreenCapturePhase? phase;
}

/// Phases of the screen-capture lifecycle where failures can occur.
enum ScreenCapturePhase {
  /// Requesting MediaProjection access (user dialog).
  requestProjection,

  /// Setting up the VirtualDisplay + ImageReader.
  setupVirtualDisplay,

  /// Reading a frame from the ImageReader.
  readFrame,

  /// Stopping or tearing down the capture session.
  stopCapture,

  /// The capture session was interrupted (app backgrounded, etc.).
  lifecycleInterruption,
}

/// Failure arising from screen-understanding (vision analysis) errors.
///
/// Covers frame-to-vision conversion, vision API errors,
/// throttling violations, cancellation, and parsing failures.
class ScreenUnderstandingFailure extends Failure {
  const ScreenUnderstandingFailure({
    required super.message,
    super.code,
    this.phase,
  });

  /// The phase during which the failure occurred.
  final ScreenUnderstandingPhase? phase;
}

/// Phases of the screen-understanding pipeline where failures can occur.
enum ScreenUnderstandingPhase {
  /// Converting a CapturedFrame to base64 for the vision API.
  frameConversion,

  /// Calling the vision API to analyze the frame.
  visionAnalysis,

  /// Parsing the vision API response into structured ScreenRepresentation.
  responseParsing,

  /// The analysis was cancelled before completion.
  cancelled,

  /// Throttle limit reached — too many analysis requests.
  throttled,

  /// Concurrent analysis already in progress — request rejected.
  concurrentConflict,

  /// No frame available to analyze.
  noFrame,
}

/// Failure arising from the floating AURA overlay subsystem.
///
/// Covers overlay permission denial, overlay view setup failure,
/// foreground service errors, position persistence issues, and
/// overlay lifecycle problems.
class FloatingAuraOverlayFailure extends Failure {
  const FloatingAuraOverlayFailure({
    required super.message,
    super.code,
    this.phase,
  });

  /// The phase during which the failure occurred.
  final FloatingAuraOverlayPhase? phase;
}

/// Phases of the floating overlay lifecycle where failures can occur.
enum FloatingAuraOverlayPhase {
  /// Requesting SYSTEM_ALERT_WINDOW permission (overlay permission).
  requestPermission,

  /// Opening the system overlay settings (Android Settings action).
  openOverlaySettings,

  /// Setting up the WindowManager overlay view.
  setupOverlayView,

  /// Starting the foreground service for the overlay.
  startForegroundService,

  /// Stopping the foreground service.
  stopForegroundService,

  /// Showing the floating overlay button.
  showOverlay,

  /// Hiding the floating overlay button.
  hideOverlay,

  /// Expanding or collapsing the overlay panel.
  togglePanel,

  /// Updating the overlay position (drag persistence).
  updatePosition,

  /// Persisting or restoring overlay position data.
  positionPersistence,

  /// The overlay session was interrupted (app backgrounded, etc.).
  lifecycleInterruption,
}

/// Failure arising from screen-search (target detection) errors.
///
/// Covers query parsing, target matching, ranking, cancellation,
/// and empty-result scenarios.
class ScreenSearchFailure extends Failure {
  const ScreenSearchFailure({
    required super.message,
    super.code,
    this.phase,
  });

  /// The phase during which the failure occurred.
  final ScreenSearchPhase? phase;
}

/// Phases of the screen-search pipeline where failures can occur.
enum ScreenSearchPhase {
  /// Parsing or validating the search query.
  queryParsing,

  /// Searching for targets within a ScreenRepresentation.
  targetMatching,

  /// Ranking or scoring search results.
  ranking,

  /// Resolving ambiguous results.
  ambiguityResolution,

  /// The search was cancelled before completion.
  cancelled,

  /// No ScreenRepresentation available to search.
  noRepresentation,
}

/// Failure arising from the VoiceScreenEngine orchestrator.
///
/// Covers all pipeline stages (voice, capture, understanding,
/// search), security/permission violations, concurrency conflicts,
/// stale-result protection, cancellation, and lifecycle issues.
class VoiceScreenFailure extends Failure {
  const VoiceScreenFailure({
    required super.message,
    super.code,
    this.phase,
  });

  /// The phase during which the failure occurred.
  final VoiceScreenPhase? phase;
}

/// Phases of the VoiceScreen pipeline where failures can occur.
enum VoiceScreenPhase {
  /// Voice recognition stage.
  voice,

  /// Screen capture stage.
  capture,

  /// Screen understanding / vision analysis stage.
  understanding,

  /// Screen search / target detection stage.
  search,

  /// Floating overlay interaction.
  overlay,

  /// Security boundary violation.
  security,

  /// Permission denial.
  permission,

  /// Engine lifecycle (dispose, post-dispose, etc.).
  lifecycle,

  /// Concurrent interaction conflict.
  concurrentConflict,

  /// Stale result from a previous session/generation.
  staleResult,

  /// The interaction was cancelled before completion.
  cancelled,
}
