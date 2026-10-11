/// Global hook so every screen (chat, voice, dashboard, live mode) that calls
/// AgentEngine.run() can route phone-control tasks to the PhoneAgent.
library;

import '../agent/agent_context.dart';
import '../agent/agent_result.dart';

typedef PhoneControlHook = Future<AgentResult?> Function(
  String userInput,
  AgentContext context,
);

/// Set once from agentEngineProvider. Returns null when the message is not a
/// phone-control task (normal chat continues as before).
PhoneControlHook? phoneControlHook;
