/// tool_recovery_adapter.dart
/// AURA Assistant – Step 20: Tool Registry & Allowlist
///
/// Adapter that bridges Step 18's RecoveryCoordinator into the
/// Tool Registry's execution pipeline.
///
/// When a tool execution fails, this adapter can attempt recovery
/// via Step 18's RecoveryCoordinator.
library;

import 'package:texo/core/errors/result.dart';
import 'package:texo/features/tool_registry/domain/models/models.dart';

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

