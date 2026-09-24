/// Abstract interface for the AURA screen-understanding subsystem.
///
/// Takes a [CapturedFrame] from the screen-capture subsystem and
/// produces a structured [ScreenRepresentation] containing visible text,
/// UI elements, screen regions, and metadata.
library;

import 'dart:async';

import '../errors/failures.dart';
import '../errors/result.dart';
import '../screen_capture/screen_capture_result.dart';
import 'screen_understanding_result.dart';
import 'screen_understanding_state.dart';

/// Contract for the screen-understanding subsystem.
///
/// Implementations delegate frame analysis to a [VisionService]
/// and add structured screen-analysis prompts, throttling,
/// deduplication, latest-frame processing, concurrent protection,
/// and cancellation.
abstract class ScreenUnderstandingService {
  /// Analyze a single captured frame.
  ///
  /// Returns [Result.success] with [ScreenRepresentation] on success,
  /// or [Result.failure] with [ScreenUnderstandingFailure] on error.
  Future<Result<ScreenRepresentation, ScreenUnderstandingFailure>>
      analyzeFrame(CapturedFrame frame);

  /// Analyze the latest frame from a continuous stream.
  ///
  /// Only the most recent frame from [frameStream] is analyzed;
  /// older frames that arrive while an analysis is in progress
  /// are discarded (latest-frame-wins strategy).
  ///
  /// Returns the result of the single analyzed frame, or a failure
  /// if the stream closes without producing a frame.
  Future<Result<ScreenRepresentation, ScreenUnderstandingFailure>>
      analyzeLatestFrame(Stream<CapturedFrame> frameStream);

  /// The current state of the subsystem.
  ScreenUnderstandingState get state;

  /// Stream of state changes for reactive UI updates.
  Stream<ScreenUnderstandingState> get stateStream;

  /// Cancel any in-progress analysis.
  ///
  /// After cancellation, [state.status] will be
  /// [ScreenUnderstandingStatus.cancelled].
  void cancel();

  /// Release resources held by this service.
  Future<void> dispose();
}
