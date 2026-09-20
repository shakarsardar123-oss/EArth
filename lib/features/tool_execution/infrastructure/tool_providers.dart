/// tool_providers.dart
/// AURA Assistant – Step 22: Tool Execution System
///
/// Tool providers — registers all built-in tools with the registry.
/// KEY FIXES:
///   - registry.allTools NOT getAllTools()
///   - riskLevel is String
///   - FAIL CLOSED: unknown tools are registered as UnknownToolHandler
library;

import 'executors/tool_executor_registry.dart';
import 'executors/device_tool.dart';
import 'executors/screen_tool.dart';
import 'executors/voice_tool.dart';
import 'executors/memory_tool.dart';
import 'executors/vision_tool.dart';
import 'executors/media_tool.dart';
import 'executors/assistant_tool.dart';
import 'executors/communication_tool.dart';
import 'executors/navigation_tool.dart';
import 'executors/system_tool.dart';
import 'executors/unknown_tool_handler.dart';

class ToolProviders {
  /// Register all built-in tools with the registry.
  static void registerAll(ToolExecutorRegistry registry) {
    registry.register(DeviceTool());
    registry.register(ScreenTool());
    registry.register(VoiceTool());
    registry.register(MemoryTool());
    registry.register(VisionTool());
    registry.register(MediaTool());
    registry.register(AssistantTool());
    registry.register(CommunicationTool());
    registry.register(NavigationTool());
    registry.register(SystemTool());
    registry.register(UnknownToolHandler());
  }

  /// List all registered tool IDs.
  static List<String> allToolIds(ToolExecutorRegistry registry) {
    return registry.allTools.map((t) => t.id).toList();
  }

  /// Check if all expected tools are registered.
  static bool validateRegistration(ToolExecutorRegistry registry) {
    final expectedIds = [
      'device', 'screen', 'voice', 'memory', 'vision',
      'media', 'assistant', 'communication', 'navigation',
      'system', 'unknown',
    ];
    for (final id in expectedIds) {
      if (registry.get(id) == null) return false;
    }
    return true;
  }
}
