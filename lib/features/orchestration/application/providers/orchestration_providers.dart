/// Step 23 — Orchestration Providers
///
/// Dependency injection wiring for the orchestration feature.
/// Wires repository *interfaces* into the AgentOrchestrator and
/// OrchestrationUseCase.
///
/// FAIL-CLOSED: all parameters are typed as repository interfaces
/// (not concrete adapters). Concrete adapters are constructed by the
/// Riverpod layer (see lib/presentation/providers/app_providers.dart)
/// and injected here through their interface. This keeps the
/// application layer free of any dependency on infrastructure/adapters,
/// preserving the Dependency Inversion Principle.

import '../../domain/orchestration_domain.dart';
import '../localization_service.dart';
import '../orchestrator/agent_orchestrator.dart';
import '../usecases/orchestration_use_case.dart';

class OrchestrationProviders {
  /// Create a fully wired AgentOrchestrator.
  ///
  /// Takes 10 repository interfaces + AppLocalizationService.
  /// voice/screen repositories are NOT passed to the orchestrator
  /// constructor (the orchestrator does not consume them directly).
  AgentOrchestrator createOrchestrator({
    required AgentEngineRepository agentEngine,
    required MemoryRepository memory,
    required ToolRegistryRepository toolRegistry,
    required SecurityRepository security,
    required PermissionRepository permission,
    required ConfirmationRepository confirmation,
    required ToolExecutionRepository execution,
    required RecoveryRepository recovery,
    required ConnectivityRepository connectivity,
    required AuditRepository audit,
    required AppLocalizationService localization,
  }) {
    return AgentOrchestrator(
      agentEngine: agentEngine,
      memory: memory,
      toolRegistry: toolRegistry,
      security: security,
      permission: permission,
      confirmation: confirmation,
      execution: execution,
      recovery: recovery,
      connectivity: connectivity,
      audit: audit,
      localization: localization,
    );
  }

  /// Create a fully wired OrchestrationUseCase.
  OrchestrationUseCase createUseCase({
    required AgentOrchestrator orchestrator,
  }) {
    return OrchestrationUseCase(orchestrator: orchestrator);
  }

  /// Convenience: create all providers at once.
  /// Returns a record with orchestrator and useCase.
  ({AgentOrchestrator orchestrator, OrchestrationUseCase useCase}) createAll({
    required AgentEngineRepository agentEngine,
    required MemoryRepository memory,
    required ToolRegistryRepository toolRegistry,
    required SecurityRepository security,
    required PermissionRepository permission,
    required ConfirmationRepository confirmation,
    required ToolExecutionRepository execution,
    required RecoveryRepository recovery,
    required ConnectivityRepository connectivity,
    required AuditRepository audit,
    required AppLocalizationService localization,
  }) {
    final orchestrator = createOrchestrator(
      agentEngine: agentEngine,
      memory: memory,
      toolRegistry: toolRegistry,
      security: security,
      permission: permission,
      confirmation: confirmation,
      execution: execution,
      recovery: recovery,
      connectivity: connectivity,
      audit: audit,
      localization: localization,
    );
    final useCase = createUseCase(orchestrator: orchestrator);
    return (orchestrator: orchestrator, useCase: useCase);
  }
}
