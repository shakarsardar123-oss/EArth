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
import 'package:aura_assistant/features/tool_registry/infrastructure/adapters/tool_security_adapter.dart';
import 'package:aura_assistant/features/tool_registry/infrastructure/adapters/tool_permission_adapter.dart';
import 'package:aura_assistant/features/tool_registry/infrastructure/adapters/tool_recovery_adapter.dart';
import 'package:aura_assistant/features/tool_registry/infrastructure/adapters/tool_memory_adapter.dart';

/// Callback type for executing a tool's core logic.
///
/// Adapters provide this callback when registering a tool.
/// The gate invokes it only after all checks pass.
typedef ToolExecutor = Future<ToolExecutionResult> Function(
  String toolId,
  Map<String, dynamic> params,
);

/// The central gate for tool execution.
///
/// This is the ONLY entry point for executing a tool. It enforces
/// the 6-gate pipeline before delegating to the tool's executor.
///
/// FAIL CLOSED: any check failure = denial. No bypasses.
abstract class ToolExecutionGate {
  /// Execute a tool by [toolId] with the given [params].
  ///
  /// The execution pipeline is:
  ///   1. Registry check (tool exists, is enabled)
  ///   2. Allowlist check (tool is allowed)
  ///   3. Security check (Step 19 approves)
  ///   4. Permission check (Step 16 grants)
  ///   5. Confirmation check (user approves, if required)
  ///   6. Execute (delegate to tool adapter)
  ///   7. On failure → Recovery (Step 18)
  ///
  /// Returns [Result.success] with [ToolExecutionResult] on success,
  /// or [Result.failure] with [ToolFailure] on denial/failure.
  Future<ToolResult<ToolExecutionResult>> execute({
    required String toolId,
    required Map<String, dynamic> params,
  });

  /// Check whether a tool CAN be executed (without actually executing it).
  ///
  /// Runs gates 1–4 (registry, allowlist, security, permission) but
  /// does NOT request user confirmation or execute the tool.
  ///
  /// Useful for UI hints (gray out tools that can't execute).
  ToolResult<ToolDefinition> canExecute(String toolId);

  /// Register an executor callback for a tool.
  ///
  /// This is how tool adapters plug their execution logic into the gate.
  void registerExecutor(String toolId, ToolExecutor executor);

  /// Unregister an executor callback.
  void unregisterExecutor(String toolId);

  /// The registry service this gate delegates to.
  ToolRegistryService get registry;

  /// The confirmation service this gate delegates to.
  ToolConfirmationService get confirmationService;

  /// The security adapter (Step 19 bridge).
  ToolSecurityAdapter get securityAdapter;

  /// The permission adapter (Step 16 bridge).
  ToolPermissionAdapter get permissionAdapter;

  /// The recovery adapter (Step 18 bridge).
  ToolRecoveryAdapter get recoveryAdapter;

  /// The memory adapter (Step 17 bridge).
  ToolMemoryAdapter get memoryAdapter;
}
