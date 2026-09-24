/// tool_recovery_adapter.dart
/// AURA Assistant – Step 20: Tool Registry & Allowlist
///
/// Adapter that bridges Step 18's RecoveryCoordinator into the
/// Tool Registry's execution pipeline.
///
/// When a tool execution fails, this adapter can attempt recovery
/// via Step 18's RecoveryCoordinator.
library;

import 'package:aura_assistant/core/errors/result.dart';
import 'package:aura_assistant/features/tool_registry/domain/models/models.dart';

/// Recovery outcome for a tool failure.
class ToolRecoveryOutcome {
  final bool recovered;
  final String? recoveredToolId;
  final String? recoveryStrategy;
  final String? message;

  const ToolRecoveryOutcome({
    required this.recovered,
    this.recoveredToolId,
    this.recoveryStrategy,
    this.message,
  });

  /// Recovery succeeded.
  factory ToolRecoveryOutcome.success({
    String? recoveredToolId,
    String? strategy,
    String? message,
  }) =>
      ToolRecoveryOutcome(
        recovered: true,
        recoveredToolId: recoveredToolId,
        recoveryStrategy: strategy,
        message: message,
      );

  /// Recovery failed.
  factory ToolRecoveryOutcome.failed({String? message}) =>
      ToolRecoveryOutcome(
        recovered: false,
        message: message ?? 'Recovery failed',
      );

  /// Recovery unavailable.
  factory ToolRecoveryOutcome.unavailable() =>
      const ToolRecoveryOutcome(
        recovered: false,
        message: 'Recovery service unavailable',
      );
}

/// Abstract interface for the recovery adapter.
///
/// Bridges Step 18's RecoveryCoordinator so the tool
/// registry does not depend on it directly.
abstract class ToolRecoveryAdapter {
  /// Attempt recovery after a tool execution failure.
  ///
  /// [toolId] – the tool that failed.
  /// [failure] – the failure details.
  /// [context] – additional context for recovery decision.
  ///
  /// Returns [ToolRecoveryOutcome] indicating whether recovery
  /// was possible and what was recovered.
  Future<ToolRecoveryOutcome> recover({
    required String toolId,
    required ToolFailure failure,
    Map<String, dynamic>? context,
  });

  /// Whether the recovery service is currently available.
  bool get isAvailable;

  /// Get the available recovery strategies (as string identifiers).
  List<String> availableStrategies();
}

/// Default implementation that does not actually recover.
///
/// Used when Step 18 is not available.
class DefaultToolRecoveryAdapter implements ToolRecoveryAdapter {
  bool _isAvailable = false;

  DefaultToolRecoveryAdapter({bool isAvailable = false})
      : _isAvailable = isAvailable;

  @override
  Future<ToolRecoveryOutcome> recover({
    required String toolId,
    required ToolFailure failure,
    Map<String, dynamic>? context,
  }) async {
    if (!_isAvailable) {
      return ToolRecoveryOutcome.unavailable();
    }

    // Default adapter: map failure phases to simple strategies.
    final phase = failure.phase;

    switch (phase) {
      case ToolFailurePhase.permission:
        // Permission failures: suggest re-requesting permissions.
        return const ToolRecoveryOutcome(
          recovered: false,
          recoveryStrategy: 'requestPermission',
          message: 'Permission failure – try requesting permissions again',
        );

      case ToolFailurePhase.confirmation:
        // Confirmation failures: suggest re-prompting.
        return const ToolRecoveryOutcome(
          recovered: false,
          recoveryStrategy: 'reconfirm',
          message: 'Confirmation denied – user may re-initiate',
        );

      case ToolFailurePhase.execution:
        // Execution failures: suggest retry.
        return const ToolRecoveryOutcome(
          recovered: false,
          recoveryStrategy: 'retry',
          message: 'Execution failed – retry may succeed',
        );

      case ToolFailurePhase.offline:
        // Offline failures: suggest waiting for connectivity.
        return const ToolRecoveryOutcome(
          recovered: false,
          recoveryStrategy: 'waitForConnectivity',
          message: 'Tool unavailable offline – wait for connectivity',
        );

      default:
        // Other phases (allowlist, security, registration, discovery):
        // No automatic recovery possible.
        return ToolRecoveryOutcome.failed(
          message: 'No recovery available for failure phase: ${phase.name}',
        );
    }
  }

  @override
  bool get isAvailable => _isAvailable;

  @override
  List<String> availableStrategies() {
    if (!_isAvailable) return const [];
    return const ['requestPermission', 'reconfirm', 'retry', 'waitForConnectivity'];
  }

  /// Configure availability.
  void setAvailable(bool available) => _isAvailable = available;
}

/// Production adapter that bridges Step 18's RecoveryCoordinator.
///
/// Translates [ToolFailure] into Step 18's error format and
/// invokes the RecoveryCoordinator.
class Step18RecoveryAdapter implements ToolRecoveryAdapter {
  /// The Step 18 RecoveryCoordinator instance.
  ///
  /// Type is dynamic to avoid direct import. Expected to implement:
  ///   recover(context, rawError, action?) -> RecoveryResult<AgentPlan>
  final dynamic _recoveryCoordinator;

  bool _isAvailable;

  Step18RecoveryAdapter({
    required dynamic recoveryCoordinator,
    bool isAvailable = true,
  })  : _recoveryCoordinator = recoveryCoordinator,
        _isAvailable = isAvailable;

  @override
  Future<ToolRecoveryOutcome> recover({
    required String toolId,
    required ToolFailure failure,
    Map<String, dynamic>? context,
  }) async {
    if (!_isAvailable || _recoveryCoordinator == null) {
      return ToolRecoveryOutcome.unavailable();
    }

    try {
      // Build recovery context for Step 18.
      final recoveryContext = {
        'toolId': toolId,
        'failurePhase': failure.phase.name,
        'failureMessage': failure.message,
        'isFailClosedDenial': failure.isFailClosedDenial,
        'isDenial': failure.isDenial,
        ...?context,
      };

      // Call Step 18's recover method.
      final result = await _recoveryCoordinator.recover(
        recoveryContext,
        failure.message,
        action: toolId,
      );

      // Translate Step 18 RecoveryResult.
      final resultStr = result.toString().toLowerCase();
      if (resultStr.contains('success') || resultStr.contains('recovered')) {
        return ToolRecoveryOutcome.success(
          recoveredToolId: toolId,
          strategy: 'step18_recovery',
          message: 'Step 18 recovered tool: $toolId',
        );
      } else {
        return ToolRecoveryOutcome.failed(
          message: 'Step 18 could not recover tool: $toolId',
        );
      }
    } catch (e) {
      return ToolRecoveryOutcome.failed(
        message: 'Step 18 recovery threw: $e',
      );
    }
  }

  @override
  bool get isAvailable => _isAvailable;

  @override
  List<String> availableStrategies() {
    if (!_isAvailable || _recoveryCoordinator == null) return const [];
    try {
      // Try to get strategies from Step 18.
      final strategies = _recoveryCoordinator.availableStrategies;
      if (strategies is List) {
        return strategies.map((s) => s.toString()).toList();
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  /// Update availability.
  void setAvailable(bool available) => _isAvailable = available;
}
