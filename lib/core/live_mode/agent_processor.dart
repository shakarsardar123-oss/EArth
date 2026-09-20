/// agent_processor.dart
/// AURA Assistant – P0 Remediation: Abstract agent processor interface
///
/// Decouples LiveModeOrchestrator from the concrete AgentEngine,
/// enabling testability without complex constructor setup.
/// AgentEngine implements this interface via its run() method.
library;

import '../agent/agent_context.dart';
import '../agent/agent_result.dart';

/// Abstract interface for processing user input with AI.
/// LiveModeOrchestrator depends on this, not on AgentEngine directly.
abstract class AgentProcessor {
  /// Process [userInput] within [context] and return a result.
  Future<AgentResult> run({
    required String userInput,
    required AgentContext context,
  });
}
