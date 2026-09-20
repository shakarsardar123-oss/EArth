/// providers.dart
/// AURA Assistant – Step 25: Dependency injection providers for the application layer.
///
/// All repositories are injected as abstract interfaces; concrete adapters
/// come from the infrastructure layer. FAIL-CLOSED defaults throughout.
library;

import '../domain/domain.dart';
import 'task_execution_coordinator.dart';

/// Creates a TaskExecutionCoordinator with all required dependencies.
/// Each parameter maps to a domain service or repository.
/// Infrastructure adapters satisfy the repository contracts.
TaskExecutionCoordinator createTaskExecutionCoordinator({
  required TaskPlannerService taskPlanner,
  required ReplannerService replanner,
  required GoalTrackerService goalTracker,
  required ResultVerifierService resultVerifier,
  required ToolSelectionService toolSelection,
  required ContextAwareExecutionService contextAwareExecution,
  required NaturalLanguageCorrectionService nlCorrection,
  required SafetyGateService safetyGate,
  required PauseResumeCancelService pauseResumeCancel,
  required TaskProgressService taskProgress,
  required AgentEngineRepository agentEngine,
  required MemoryRepository memory,
  required ToolRegistryRepository toolRegistry,
  required ToolExecutionRepository toolExecution,
  required SecurityRepository security,
  required PermissionRepository permission,
  required ConfirmationRepository confirmation,
  required RecoveryRepository recovery,
  required ConnectivityRepository connectivity,
  required AuditRepository audit,
  required TriggerRepository trigger,
}) {
  return TaskExecutionCoordinator(
    taskPlanner: taskPlanner,
    replanner: replanner,
    goalTracker: goalTracker,
    resultVerifier: resultVerifier,
    toolSelection: toolSelection,
    contextAwareExecution: contextAwareExecution,
    nlCorrection: nlCorrection,
    safetyGate: safetyGate,
    pauseResumeCancel: pauseResumeCancel,
    taskProgress: taskProgress,
    agentEngine: agentEngine,
    memory: memory,
    toolRegistry: toolRegistry,
    toolExecution: toolExecution,
    security: security,
    permission: permission,
    confirmation: confirmation,
    recovery: recovery,
    connectivity: connectivity,
    audit: audit,
    trigger: trigger,
  );
}

/// Default Kurdish Sorani locale for all advanced agent operations.
const String kDefaultLocale = 'ku';
