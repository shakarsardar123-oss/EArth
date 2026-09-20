/// default_tool_execution_gate.dart
/// AURA Assistant – Step 20: Tool Registry & Allowlist
///
/// Concrete implementation of [ToolExecutionGate].
///
/// 6-gate execution pipeline:
/// 1. Registry gate — tool must be registered
/// 2. Allowlist gate — tool must be allowed
/// 3. Security gate — security adapter must approve (Step 19)
/// 4. Permission gate — permissions must be granted (Step 16)
/// 5. Confirmation gate — user confirmation if required
/// 6. Execution — invoke the actual tool executor
///
/// Recovery is attempted on failure via the recovery adapter (Step 18).
/// Memory context is provided via the memory adapter (Step 17).
///
/// FAIL CLOSED: any unknown state, any exception → execution denied.
library;

import 'dart:async';

import 'package:aura_assistant/core/errors/result.dart';
import 'package:aura_assistant/features/tool_registry/domain/models/models.dart';
import 'package:aura_assistant/features/tool_registry/domain/services/services.dart';
import 'package:aura_assistant/features/tool_registry/application/application.dart';
import 'package:aura_assistant/features/tool_registry/infrastructure/adapters/adapters.dart';

/// Concrete implementation of [ToolExecutionGate].
///
/// Implements the full 6-gate pipeline with fail-closed behavior.
/// Each gate must pass before the next is checked.
class DefaultToolExecutionGate implements ToolExecutionGate {
  final ToolRegistryService _registryService;
  final ToolConfirmationService _confirmationService;
  final ToolSecurityAdapter? _securityAdapter;
  final ToolPermissionAdapter? _permissionAdapter;
  final ToolRecoveryAdapter? _recoveryAdapter;
  final ToolMemoryAdapter? _memoryAdapter;

  /// Registered tool executors, keyed by toolId.
  final Map<String, ToolExecutor> _executors = {};

  DefaultToolExecutionGate({
    required ToolRegistryService registryService,
    required ToolConfirmationService confirmationService,
    ToolSecurityAdapter? securityAdapter,
    ToolPermissionAdapter? permissionAdapter,
    ToolRecoveryAdapter? recoveryAdapter,
    ToolMemoryAdapter? memoryAdapter,
  })  : _registryService = registryService,
        _confirmationService = confirmationService,
        _securityAdapter = securityAdapter,
        _permissionAdapter = permissionAdapter,
        _recoveryAdapter = recoveryAdapter,
        _memoryAdapter = memoryAdapter;

  // ─── Executor Registration ──────────────────────────────────────

  @override
  ToolResult<void> registerExecutor(String toolId, ToolExecutor executor) {
    _executors[toolId] = executor;
    return Result.success(null);
  }

  @override
  ToolResult<void> unregisterExecutor(String toolId) {
    _executors.remove(toolId);
    return Result.success(null);
  }

  // ─── Execution ─────────────────────────────────────────────────

  @override
  Future<ToolResult<ToolExecutionResult>> execute(
    String toolId, {
    Map<String, dynamic>? parameters,
    String? context,
  }) async {
    try {
      // ── Gate 1: Registry ─────────────────────────────────
      final regResult = _registryService.getDefinition(toolId);
      if (regResult.isFailure) {
        return Result.failure(
          ToolFailure.registry(
            message: 'Gate 1 failed: tool not registered: $toolId',
          ),
        );
      }
      final definition = regResult.asSuccess.value;

      // Check if tool is enabled.
      if (!definition.isEnabled) {
        // FAIL CLOSED: disabled tool = denied.
        return Result.failure(
          ToolFailure.registry(
            message: 'Gate 1 failed: tool is disabled: $toolId',
          ),
        );
      }

      // ── Gate 2: Allowlist ─────────────────────────────────
      if (!_registryService.isAllowed(toolId)) {
        // FAIL CLOSED: not in allowlist = denied.
        return Result.failure(
          ToolFailure.allowlist(
            message: 'Gate 2 failed: tool not in allowlist: $toolId',
          ),
        );
      }

      // ── Gate 3: Security ──────────────────────────────────
      if (_securityAdapter != null) {
        final secResult = await _securityAdapter.check(definition);
        if (secResult.verdict != ToolSecurityVerdict.allowed) {
          // FAIL CLOSED: security verdict != allowed = denied.
          return Result.failure(
            ToolFailure.security(
              message:
                  'Gate 3 failed: security verdict=${secResult.verdict.name}: '
                  '${secResult.reason}',
            ),
          );
        }
      } else {
        // No security adapter — skip this gate (configuration-dependent).
        // If security is required but not available, FAIL CLOSED.
        if (definition.riskLevel == ToolRiskLevel.critical ||
            definition.riskLevel == ToolRiskLevel.high) {
          return Result.failure(
            ToolFailure.security(
              message:
                  'Gate 3 failed: no security adapter available for '
                  '${definition.riskLevel.name} risk tool: $toolId',
            ),
          );
        }
      }

      // ── Gate 4: Permission ────────────────────────────────
      if (_permissionAdapter != null && definition.requiredPermissions.isNotEmpty) {
        for (final permId in definition.requiredPermissions) {
          final permResult = await _permissionAdapter.check(permId);
          if (!permResult.isGranted) {
            // FAIL CLOSED: permission not granted = denied.
            return Result.failure(
              ToolFailure.permission(
                message:
                    'Gate 4 failed: permission not granted: $permId. '
                    '${permResult.reason}',
              ),
            );
          }
        }
      } else if (_permissionAdapter == null &&
          definition.requiredPermissions.isNotEmpty) {
        // No permission adapter but tool requires permissions → FAIL CLOSED.
        return Result.failure(
          ToolFailure.permission(
            message:
                'Gate 4 failed: no permission adapter available for tool '
                'requiring permissions: $toolId',
          ),
        );
      }

      // ── Gate 5: Confirmation ──────────────────────────────
      final confResult = await _confirmationService.requestConfirmation(
        definition,
        message: context,
      );
      if (confResult != ConfirmationResult.confirmed) {
        // FAIL CLOSED: not confirmed = denied.
        return Result.failure(
          ToolFailure.confirmation(
            message:
                'Gate 5 failed: confirmation result=${confResult.name}',
          ),
        );
      }

      // ── Gate 6: Execution ─────────────────────────────────
      final executor = _executors[toolId];
      if (executor == null) {
        // FAIL CLOSED: no executor registered = denied.
        return Result.failure(
          ToolFailure.execution(
            message: 'Gate 6 failed: no executor registered for tool: $toolId',
          ),
        );
      }

      // Get memory context if available.
      String? memoryContext;
      if (_memoryAdapter != null) {
        final memResult = await _memoryAdapter.getContext(toolId);
        if (memResult.isSuccess) {
          memoryContext = memResult.asSuccess.context;
        }
        // Memory failure does not block execution.
      }

      // Execute the tool.
      final execResult = await executor(
        parameters ?? {},
        memoryContext: memoryContext,
        toolContext: context,
      );

      // Record execution in registry.
      if (_registryService is DefaultToolRegistryService) {
        (_registryService as DefaultToolRegistryService)
            .recordExecution(execResult);
      }

      return Result.success(execResult);
    } on TimeoutException {
      // FAIL CLOSED: timeout = execution failure.
      return Result.failure(
        ToolFailure.execution(
          message: 'Execution timed out for tool: $toolId',
        ),
      );
    } catch (e) {
      // FAIL CLOSED: any exception = execution failure.
      // Attempt recovery before returning failure.
      return _attemptRecovery(toolId, e, parameters: parameters);
    }
  }

  // ─── Pre-flight Checks ─────────────────────────────────────────

  @override
  Future<ToolExecutionReadiness> checkReadiness(String toolId) async {
    try {
      // Gate 1: Registry.
      final regResult = _registryService.getDefinition(toolId);
      if (regResult.isFailure) {
        return ToolExecutionReadiness.notReady(
          reason: 'Tool not registered: $toolId',
        );
      }
      final definition = regResult.asSuccess.value;

      if (!definition.isEnabled) {
        return ToolExecutionReadiness.notReady(
          reason: 'Tool is disabled: $toolId',
        );
      }

      // Gate 2: Allowlist.
      if (!_registryService.isAllowed(toolId)) {
        return ToolExecutionReadiness.notReady(
          reason: 'Tool not in allowlist: $toolId',
        );
      }

      // Gate 3: Security.
      if (_securityAdapter != null) {
        final secResult = await _securityAdapter.check(definition);
        if (secResult.verdict != ToolSecurityVerdict.allowed) {
          return ToolExecutionReadiness.notReady(
            reason: 'Security verdict: ${secResult.verdict.name}',
          );
        }
      }

      // Gate 4: Permission.
      if (_permissionAdapter != null &&
          definition.requiredPermissions.isNotEmpty) {
        for (final permId in definition.requiredPermissions) {
          final permResult = await _permissionAdapter.check(permId);
          if (!permResult.isGranted) {
            return ToolExecutionReadiness.notReady(
              reason: 'Permission not granted: $permId',
            );
          }
        }
      }

      // Gate 5: Confirmation (check availability only, don't prompt).
      if (!_confirmationService.isAvailable &&
          definition.effectiveConfirmationPolicy != ConfirmationPolicy.never) {
        return ToolExecutionReadiness.notReady(
          reason: 'Confirmation service unavailable',
        );
      }

      // Gate 6: Executor.
      if (!_executors.containsKey(toolId)) {
        return ToolExecutionReadiness.notReady(
          reason: 'No executor registered: $toolId',
        );
      }

      return ToolExecutionReadiness.ready;
    } catch (e) {
      // FAIL CLOSED: any exception = not ready.
      return ToolExecutionReadiness.notReady(
        reason: 'Readiness check failed: $e',
      );
    }
  }

  // ─── Allowlist Quick Check ─────────────────────────────────────

  @override
  bool isToolAllowed(String toolId) => _registryService.isAllowed(toolId);

  @override
  bool isToolRegistered(String toolId) {
    final result = _registryService.getDefinition(toolId);
    return result.isSuccess;
  }

  @override
  ToolDefinition? getDefinition(String toolId) {
    final result = _registryService.getDefinition(toolId);
    return result.isSuccess ? result.asSuccess.value : null;
  }

  @override
  List<ToolDefinition> getRegisteredTools() => _registryService.getAll();

  @override
  ToolExecutor? getExecutor(String toolId) => _executors[toolId];

  // ─── Recovery ─────────────────────────────────────────────────

  /// Attempt recovery after an execution failure.
  ///
  /// FAIL CLOSED: if recovery fails or adapter is unavailable,
  /// still return a failure result.
  Future<ToolResult<ToolExecutionResult>> _attemptRecovery(
    String toolId,
    Object error, {\n    Map<String, dynamic>? parameters,
  }) async {
    if (_recoveryAdapter == null) {
      // No recovery adapter → return the failure directly.
      return Result.failure(
        ToolFailure.execution(
          message: 'Execution failed (no recovery adapter): $error',
        ),
      );
    }

    try {
      final outcome = await _recoveryAdapter.recover(
        toolId,
        error.toString(),
      );

      if (outcome.isRecovered && outcome.shouldRetry) {
        // Retry once.
        final retryResult = await _retryOnce(toolId, parameters: parameters);
        if (retryResult.isSuccess) {
          return retryResult;
        }
      }
    } catch (_) {
      // Recovery itself failed → still return failure.
    }

    return Result.failure(
      ToolFailure.execution(
        message: 'Execution failed (recovery unsuccessful): $error',
      ),
    );
  }

  /// Single retry attempt after recovery.
  Future<ToolResult<ToolExecutionResult>> _retryOnce(
    String toolId, {\n    Map<String, dynamic>? parameters,
  }) async {
    final executor = _executors[toolId];
    if (executor == null) {
      return Result.failure(
        ToolFailure.execution(
          message: 'Retry failed: no executor for: $toolId',
        ),
      );
    }

    try {
      final result = await executor(
        parameters ?? {},
        memoryContext: null,
        toolContext: null,
      );

      if (_registryService is DefaultToolRegistryService) {
        (_registryService as DefaultToolRegistryService)
            .recordExecution(result);
      }

      return Result.success(result);
    } catch (e) {
      return Result.failure(
        ToolFailure.execution(
          message: 'Retry failed: $e',
        ),
      );
    }
  }
}
