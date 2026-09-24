/// tool_execution_gate.dart
/// AURA Assistant – Step 20: Tool Registry & Allowlist
///
/// The central gate that ALL tool execution must pass through.
///
/// Execution pipeline (each gate must pass before the next):
///   1. REGISTRY  — tool must be registered and enabled
///   2. ALLOWLIST — tool must have an allowlist entry with isAllowed=true
///   3. SECURITY  — Step 19's AgentSecurityService must approve
///   4. PERMISSION — Step 16's CentralPermissionService must grant
///   5. CONFIRMATION — user confirmation if required by policy
///   6. EXECUTE   — delegate to the tool's adapter
///   7. RECOVERY  — on failure, delegate to Step 18's RecoveryCoordinator
///
/// FAIL CLOSED: any gate failure → tool is denied.
/// This is the core security boundary for tool execution.
library;

import 'package:aura_assistant/core/errors/result.dart';
import 'package:aura_assistant/features/tool_registry/domain/models/models.dart';
import 'package:aura_assistant/features/tool_registry/domain/services/tool_registry_service.dart';
import 'package:aura_assistant/features/tool_registry/domain/services/tool_confirmation_service.dart';
// TODO(CATEGORY B — Architecture Violation): Application layer should not import infrastructure adapters.
// These should depend on domain interfaces with infrastructure providing concrete implementations.
// See: tool_registry/infrastructure/adapters/{tool_security,tool_permission,tool_recovery,tool_memory}_adapter.dart
import 'package:aura_assistant/features/tool_registry/application/contracts/tool_security_adapter.dart';
import 'package:aura_assistant/features/tool_registry/application/contracts/tool_permission_adapter.dart';
import 'package:aura_assistant/features/tool_registry/application/contracts/tool_recovery_adapter.dart';
import 'package:aura_assistant/features/tool_registry/application/contracts/tool_memory_adapter.dart';

/// Callback type for executing a tool's core logic.
///
/// Adapters provide this callback when registering a tool.
/// The gate invokes it only after all checks pass.
typedef ToolExecutor = Future<ToolExecutionResult> Function(
  Map<String, dynamic> params, {
  String? memoryContext,
  String? toolContext,
});

class ToolExecutionReadiness {
  final bool isReady;
  final String? reason;

  const ToolExecutionReadiness._({
    required this.isReady,
    this.reason,
  });

  static const ToolExecutionReadiness ready =
      ToolExecutionReadiness._(isReady: true);

  factory ToolExecutionReadiness.notReady({
    required String reason,
  }) =>
      ToolExecutionReadiness._(
        isReady: false,
        reason: reason,
      );
}

abstract class ToolExecutionGate {
  Future<ToolResult<ToolExecutionResult>> execute(
    String toolId, {
    Map<String, dynamic>? parameters,
    String? context,
  });

  Future<ToolExecutionReadiness> checkReadiness(String toolId);

  bool isToolAllowed(String toolId);
  bool isToolRegistered(String toolId);
  ToolDefinition? getDefinition(String toolId);
  List<ToolDefinition> getRegisteredTools();

  ToolExecutor? getExecutor(String toolId);

  ToolResult<void> registerExecutor(
    String toolId,
    ToolExecutor executor,
  );

  ToolResult<void> unregisterExecutor(String toolId);

  ToolRegistryService get registry;
  ToolConfirmationService get confirmationService;
  ToolSecurityAdapter get securityAdapter;
  ToolPermissionAdapter get permissionAdapter;
  ToolRecoveryAdapter get recoveryAdapter;
  ToolMemoryAdapter get memoryAdapter;
}
