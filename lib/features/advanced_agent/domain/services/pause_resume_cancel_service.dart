/// pause_resume_cancel_service.dart
/// AURA Assistant – Step 25: Capability 9 — Pause/Resume/Cancel
///
/// Abstract service interface for controlling task execution lifecycle.
library;

import '../models/pause_resume_state.dart';

/// Service responsible for pausing, resuming, and cancelling
/// task execution.
abstract class PauseResumeCancelService {
  /// Pause a running task/plan.
  /// Returns the updated [PauseResumeRecord], or null if pause fails.
  PauseResumeRecord? pause({
    required String planId,
    String? stepId,
    String? reason,
    required String requestedBy,
  });

  /// Resume a paused task/plan.
  /// Returns the updated [PauseResumeRecord], or null if resume fails.
  PauseResumeRecord? resume({
    required String planId,
    String? stepId,
    required String requestedBy,
  });

  /// Cancel a task/plan (cannot be resumed).
  /// Returns the updated [PauseResumeRecord], or null if cancel fails.
  PauseResumeRecord? cancel({
    required String planId,
    String? stepId,
    String? reason,
    required String requestedBy,
  });

  /// Get the current pause/resume state for a plan.
  PauseResumeState stateForPlan(String planId);

  /// Get the current pause/resume state for a step.
  PauseResumeState stateForStep(String planId, String stepId);

  /// Whether a plan can be paused.
  bool canPause(String planId);

  /// Whether a plan can be resumed.
  bool canResume(String planId);

  /// Whether a plan can be cancelled.
  bool canCancel(String planId);
}
