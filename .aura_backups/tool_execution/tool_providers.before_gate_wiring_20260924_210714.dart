/// tool_providers.dart
/// AURA Assistant – Step 22: Tool Execution System
///
/// Riverpod providers for tool execution state management.
/// Manages: tool registry, execution state, background tasks,
/// voice execution, offline status, and selection results.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/tool_execution_context.dart';
import '../domain/models/tool_input.dart';
import '../domain/models/tool_output.dart';
import '../domain/models/tool_execution_metadata.dart';
import '../domain/services/tool_interface.dart';
import '../infrastructure/executors/tool_executor_registry.dart';
import '../infrastructure/executors/executors.dart';
import '../infrastructure/adapters/adapters.dart';
import '../application/tool_execution_engine.dart';
import '../application/tool_selection.dart';
import '../application/background_execution.dart';
import '../application/voice_first_execution.dart';
import '../application/offline_capability.dart';
import '../application/cancellation_token.dart';

// ─── Tool Registry Provider ───

/// Provider for the ToolExecutorRegistry.
/// Registers all 12 tool implementations.
final toolExecutorRegistryProvider = Provider<ToolExecutorRegistry>((ref) {
  final registry = ToolExecutorRegistry();
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
  registry.register(RecoveryTool());
  return registry;
});

// ─── Execution Engine Provider ───

/// Provider for the ToolExecutionEngine.
final toolExecutionEngineProvider = Provider<ToolExecutionEngine>((ref) {
  final registry = ref.watch(toolExecutorRegistryProvider);
  final gateAdapter = Step20GateAdapter();
  final securityBridge = Step19SecurityBridge();
  final retryBridge = Step18RetryBridge();
  final confirmationAdapter = Step20ConfirmationAdapter();

  return ToolExecutionEngine(
    registry: registry,
    gateAdapter: gateAdapter,
    securityBridge: securityBridge,
    retryBridge: retryBridge,
    confirmationAdapter: confirmationAdapter,
  );
});

// ─── Tool Selection Provider ───

/// Provider for the ToolSelection service.
final toolSelectionProvider = Provider<ToolSelection>((ref) {
  final registry = ref.watch(toolExecutorRegistryProvider);
  return ToolSelection(registry: registry);
});

// ─── Background Execution Provider ───

/// Provider for the BackgroundExecution manager.
final backgroundExecutionProvider = Provider<BackgroundExecution>((ref) {
  final engine = ref.watch(toolExecutionEngineProvider);
  return BackgroundExecution(engine: engine);
});

// ─── Voice-First Execution Provider ───

/// Provider for the VoiceFirstExecution service.
final voiceFirstExecutionProvider = Provider<VoiceFirstExecution>((ref) {
  final engine = ref.watch(toolExecutionEngineProvider);
  final registry = ref.watch(toolExecutorRegistryProvider);
  return VoiceFirstExecution(engine: engine, registry: registry);
});

// ─── Offline Capability Provider ───

/// Provider for the OfflineCapability manager.
final offlineCapabilityProvider = Provider<OfflineCapability>((ref) {
  final registry = ref.watch(toolExecutorRegistryProvider);
  final engine = ref.watch(toolExecutionEngineProvider);
  return OfflineCapability(registry: registry, engine: engine);
});

// ─── State Notifiers ───

/// State for a single tool execution.
class ToolExecutionState {
  final bool isExecuting;
  final ToolOutput? output;
  final ToolExecutionMetadata? metadata;
  final String? error;

  const ToolExecutionState({
    this.isExecuting = false,
    this.output,
    this.metadata,
    this.error,
  });

  ToolExecutionState executing() => const ToolExecutionState(isExecuting: true);

  ToolExecutionState completed(ToolOutput output, ToolExecutionMetadata? metadata) =>
      ToolExecutionState(isExecuting: false, output: output, metadata: metadata);

  ToolExecutionState failed(String error) =>
      ToolExecutionState(isExecuting: false, error: error);
}

/// State notifier for tool execution.
class ToolExecutionNotifier extends StateNotifier<ToolExecutionState> {
  final ToolExecutionEngine _engine;

  ToolExecutionNotifier(this._engine) : super(const ToolExecutionState());

  Future<void> execute({
    required String toolId,
    required Map<String, dynamic> params,
    required ToolExecutionContext context,
  }) async {
    state = state.executing();
    try {
      final result = await _engine.executeTool(
        toolId: toolId,
        params: params,
        context: context,
      );
      state = state.completed(result.output, result.metadata);
    } catch (e) {
      state = state.failed('Execution failed');
    }
  }
}

/// Provider for tool execution state notifier.
final toolExecutionNotifierProvider =
    StateNotifierProvider<ToolExecutionNotifier, ToolExecutionState>((ref) {
  final engine = ref.watch(toolExecutionEngineProvider);
  return ToolExecutionNotifier(engine);
});

// ─── Background Task List Provider ───

/// Provider for the list of background tasks.
final backgroundTaskListProvider =
    Provider<List<BackgroundTask>>((ref) {
  final bgExec = ref.watch(backgroundExecutionProvider);
  return bgExec.getTasks();
});

// ─── Unread Overlay Results Provider ───

/// Provider for unread overlay results.
final unreadOverlayResultsProvider =
    Provider<List<OverlayResult>>((ref) {
  final bgExec = ref.watch(backgroundExecutionProvider);
  return bgExec.getUnreadOverlayResults();
});

// ─── Offline Status Provider ───

/// Provider for current offline status.
final offlineStatusProvider = StateProvider<OfflineStatus>((ref) {
  return OfflineStatus.online;
});

// ─── Available Tools Provider ───

/// Provider for currently available tools (filtered by offline status).
final availableToolsProvider = Provider<List<Tool>>((ref) {
  final offlineStatus = ref.watch(offlineStatusProvider);
  final registry = ref.watch(toolExecutorRegistryProvider);

  if (offlineStatus == OfflineStatus.online) {
    return registry.allTools;
  }
  return registry.allTools.where((t) => t.supportsOffline).toList();
});

// ─── Tool Discovery Provider ───

/// Provider for tool discovery via Step 20 adapter.
final toolDiscoveryProvider = Provider<Step20DiscoveryAdapter>((ref) {
  return Step20DiscoveryAdapter();
});
