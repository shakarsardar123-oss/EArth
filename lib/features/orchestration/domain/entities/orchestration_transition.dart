/// Step 23 — Orchestration Transition Rules
///
/// Defines the legal state transitions in the orchestration lifecycle.
/// FAIL-CLOSED: any transition not in this table is invalid and results in [failed].

import '../value_objects/orchestration_state.dart';

class OrchestrationTransition {
  final OrchestrationPhase from;
  final OrchestrationPhase to;
  final String description;

  const OrchestrationTransition({
    required this.from,
    required this.to,
    required this.description,
  });

  /// The canonical legal transitions for the orchestration lifecycle.
  ///
  /// idle → understanding
  /// understanding → planning | failed
  /// planning → memoryLookup | toolDiscovery | responding | failed
  /// memoryLookup → planning | toolDiscovery | failed
  /// toolDiscovery → securityChecking | responding | failed
  /// securityChecking → permissionChecking | failed
  /// permissionChecking → awaitingConfirmation | executing | failed
  /// awaitingConfirmation → executing | failed | cancelled
  /// executing → verifying | recovering | failed | cancelled
  /// verifying → completed | recovering | failed
  /// recovering → executing | planning | failed
  /// responding → completed
  /// completed → (terminal)
  /// failed → (terminal)
  /// cancelled → (terminal)
  static const List<OrchestrationTransition> legal = [
    OrchestrationTransition(from: OrchestrationPhase.idle, to: OrchestrationPhase.understanding, description: 'Begin understanding user request'),
    OrchestrationTransition(from: OrchestrationPhase.understanding, to: OrchestrationPhase.planning, description: 'Understanding complete, begin planning'),
    OrchestrationTransition(from: OrchestrationPhase.understanding, to: OrchestrationPhase.failed, description: 'Understanding failed'),
    OrchestrationTransition(from: OrchestrationPhase.planning, to: OrchestrationPhase.memoryLookup, description: 'Plan requires memory context'),
    OrchestrationTransition(from: OrchestrationPhase.planning, to: OrchestrationPhase.toolDiscovery, description: 'Plan requires a tool'),
    OrchestrationTransition(from: OrchestrationPhase.planning, to: OrchestrationPhase.responding, description: 'Plan is direct response'),
    OrchestrationTransition(from: OrchestrationPhase.planning, to: OrchestrationPhase.failed, description: 'Planning failed'),
    OrchestrationTransition(from: OrchestrationPhase.memoryLookup, to: OrchestrationPhase.planning, description: 'Memory context enriched, re-plan'),
    OrchestrationTransition(from: OrchestrationPhase.memoryLookup, to: OrchestrationPhase.toolDiscovery, description: 'Memory enriched, proceed to tool discovery'),
    OrchestrationTransition(from: OrchestrationPhase.memoryLookup, to: OrchestrationPhase.failed, description: 'Memory lookup failed (safe degradation)'),
    OrchestrationTransition(from: OrchestrationPhase.toolDiscovery, to: OrchestrationPhase.securityChecking, description: 'Tool found, check security'),
    OrchestrationTransition(from: OrchestrationPhase.toolDiscovery, to: OrchestrationPhase.responding, description: 'No tool needed, direct response'),
    OrchestrationTransition(from: OrchestrationPhase.toolDiscovery, to: OrchestrationPhase.failed, description: 'Tool discovery failed'),
    OrchestrationTransition(from: OrchestrationPhase.securityChecking, to: OrchestrationPhase.permissionChecking, description: 'Security cleared, check permissions'),
    OrchestrationTransition(from: OrchestrationPhase.securityChecking, to: OrchestrationPhase.failed, description: 'Security blocked request'),
    OrchestrationTransition(from: OrchestrationPhase.permissionChecking, to: OrchestrationPhase.awaitingConfirmation, description: 'Permissions granted, await confirmation'),
    OrchestrationTransition(from: OrchestrationPhase.permissionChecking, to: OrchestrationPhase.executing, description: 'Permissions auto-granted for low risk, skip confirmation'),
    OrchestrationTransition(from: OrchestrationPhase.permissionChecking, to: OrchestrationPhase.failed, description: 'Permissions denied'),
    OrchestrationTransition(from: OrchestrationPhase.awaitingConfirmation, to: OrchestrationPhase.executing, description: 'Confirmation granted, execute'),
    OrchestrationTransition(from: OrchestrationPhase.awaitingConfirmation, to: OrchestrationPhase.failed, description: 'Confirmation denied'),
    OrchestrationTransition(from: OrchestrationPhase.awaitingConfirmation, to: OrchestrationPhase.cancelled, description: 'User cancelled during confirmation'),
    OrchestrationTransition(from: OrchestrationPhase.executing, to: OrchestrationPhase.verifying, description: 'Execution succeeded, verify'),
    OrchestrationTransition(from: OrchestrationPhase.executing, to: OrchestrationPhase.recovering, description: 'Execution failed, attempt recovery'),
    OrchestrationTransition(from: OrchestrationPhase.executing, to: OrchestrationPhase.failed, description: 'Execution failed irrecoverably'),
    OrchestrationTransition(from: OrchestrationPhase.executing, to: OrchestrationPhase.cancelled, description: 'User cancelled during execution'),
    OrchestrationTransition(from: OrchestrationPhase.verifying, to: OrchestrationPhase.completed, description: 'Verification passed, complete'),
    OrchestrationTransition(from: OrchestrationPhase.verifying, to: OrchestrationPhase.recovering, description: 'Verification failed, attempt recovery'),
    OrchestrationTransition(from: OrchestrationPhase.verifying, to: OrchestrationPhase.failed, description: 'Verification failed irrecoverably'),
    OrchestrationTransition(from: OrchestrationPhase.recovering, to: OrchestrationPhase.executing, description: 'Recovery succeeded, retry execution'),
    OrchestrationTransition(from: OrchestrationPhase.recovering, to: OrchestrationPhase.planning, description: 'Recovery suggests replanning'),
    OrchestrationTransition(from: OrchestrationPhase.recovering, to: OrchestrationPhase.failed, description: 'Recovery exhausted, fail'),
    OrchestrationTransition(from: OrchestrationPhase.responding, to: OrchestrationPhase.completed, description: 'Response delivered, complete'),
    // Terminal: no transitions out of completed, failed, cancelled
  ];

  /// Whether transitioning from [fromPhase] to [toPhase] is legal.
  static bool isLegal(OrchestrationPhase fromPhase, OrchestrationPhase toPhase) {
    return legal.any((t) => t.from == fromPhase && t.to == toPhase);
  }

  /// FAIL-CLOSED: returns [toPhase] if legal, otherwise [OrchestrationPhase.failed].
  static OrchestrationPhase safeTransition(
    OrchestrationPhase fromPhase,
    OrchestrationPhase toPhase,
  ) {
    if (isLegal(fromPhase, toPhase)) return toPhase;
    return OrchestrationPhase.failed;
  }
}
