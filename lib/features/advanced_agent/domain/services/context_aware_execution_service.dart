/// context_aware_execution_service.dart
/// AURA Assistant – Step 25: Capability 6 — Context-Aware Execution
///
/// Abstract service interface for context-aware execution adaptation.
library;

import '../models/context_aware_config.dart';
import '../models/advanced_task_plan.dart';

/// Service responsible for adapting execution behavior based on
/// runtime context (connectivity, memory, locale).
abstract class ContextAwareExecutionService {
  /// Get the current execution context mode.
  ExecutionContextMode currentMode();

  /// Determine the execution context mode based on current conditions.
  ExecutionContextMode determineMode({
    required bool isOnline,
    required bool memoryAvailable,
  required ContextAwareConfig config,
  });

  /// Adapt a plan for offline/degraded execution.
  /// Returns a modified plan, or null if adaptation fails (fail-closed).
  AdvancedTaskPlan? adaptPlanForMode({
    required AdvancedTaskPlan plan,
    required ExecutionContextMode mode,
    required String locale,
  });

  /// Get the current configuration.
  ContextAwareConfig get config;

  /// Whether execution should degrade safely on error.
  /// FAIL-CLOSED: defaults to true.
  bool get degradeSafelyOnError;
}
