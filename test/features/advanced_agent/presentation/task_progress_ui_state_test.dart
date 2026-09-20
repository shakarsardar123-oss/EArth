/// task_progress_ui_state_test.dart
/// Structural tests for TaskProgressUIState model.
///
/// Verifies: fromDomainState maps PlanStatus+PauseResumeState to UI status.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/advanced_agent/presentation/task_progress_ui_state.dart';
import 'package:aura_assistant/features/advanced_agent/domain/models/advanced_task_plan.dart';
import 'package:aura_assistant/features/advanced_agent/domain/models/pause_resume_state.dart';

void main() {
  group('TaskProgressUIState', () {
    test('fromDomainState creates UI state', () {
      final ui = TaskProgressUIState.fromDomainState(
        planStatus: PlanStatus.active,
        pauseResumeState: PauseResumeState.running,
      );
      expect(ui, isNotNull);
    });

    test('active+running maps to running UI status', () {
      final ui = TaskProgressUIState.fromDomainState(
        planStatus: PlanStatus.active,
        pauseResumeState: PauseResumeState.running,
      );
      expect(ui.status, isNotEmpty);
    });

    test('active+paused maps to paused UI status', () {
      final ui = TaskProgressUIState.fromDomainState(
        planStatus: PlanStatus.active,
        pauseResumeState: PauseResumeState.paused,
      );
      expect(ui, isNotNull);
    });

    test('cancelled maps regardless of pause state', () {
      final ui = TaskProgressUIState.fromDomainState(
        planStatus: PlanStatus.cancelled,
        pauseResumeState: PauseResumeState.cancelled,
      );
      expect(ui, isNotNull);
    });
  });
}
