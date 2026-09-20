/// tool_execution_metadata.dart
/// AURA Assistant – Step 22: Tool Execution System
///
/// Execution metadata — tracks phases, audit trail, and timing.
/// Immutable audit trail for tool execution lifecycle.
///
/// FAIL CLOSED: missing metadata defaults to restrictive values.
library;

import 'package:meta/meta.dart';

/// Canonical execution phases for tool execution.
/// Exactly 12 values — do NOT add or remove.
enum ToolExecutionPhase {
  requested,
  validating,
  confirming,
  sanitizing,
  executing,
  normalizing,
  completed,
  failed,
  cancelled,
  timedOut,
  denied,
  failClosed;

  /// Whether this phase represents a terminal state.
  bool get isTerminal =>
      this == completed ||
      this == failed ||
      this == cancelled ||
      this == timedOut ||
      this == denied ||
      this == failClosed;

  /// Whether this phase represents an active (non-terminal) state.
  bool get isActive => !isTerminal;

  /// Whether this phase indicates a failure.
  bool get isFailed =>
      this == failed ||
      this == cancelled ||
      this == timedOut ||
      this == denied ||
      this == failClosed;
}

/// A single audit trail entry.
@immutable
class AuditEntry {
  /// What action was performed.
  final String action;

  /// Human-readable description of the action.
  final String description;

  /// When this action occurred.
  final DateTime timestamp;

  /// Additional details (optional).
  final Map<String, dynamic>? details;

  const AuditEntry({
    required this.action,
    required this.description,
    required this.timestamp,
    this.details,
  });

  @override
  String toString() =>
      'AuditEntry($action at $timestamp: $description)';
}

/// Execution metadata — immutable audit trail and phase tracking.
@immutable
class ToolExecutionMetadata {
  /// Current execution phase.
  final ToolExecutionPhase currentPhase;

  /// Audit trail entries.
  final List<AuditEntry> auditEntries;

  /// Total execution duration in milliseconds.
  final int? durationMs;

  /// Recovery strategy applied (if any).
  final String? recoveryStrategy;

  /// Number of retries performed.
  final int retryCount;

  /// The tool being executed.
  final String toolId;

  /// The execution ID.
  final String executionId;

  const ToolExecutionMetadata({
    this.currentPhase = ToolExecutionPhase.requested,
    this.auditEntries = const [],
    this.durationMs,
    this.recoveryStrategy,
    this.retryCount = 0,
    required this.toolId,
    required this.executionId,
  });

  /// Whether execution is in a terminal phase.
  bool get isTerminal => currentPhase.isTerminal;

  /// Whether execution has failed.
  bool get hasFailed => currentPhase.isFailed;

  /// Add an audit entry and advance phase (returns new metadata).
  ToolExecutionMetadata withPhase(
    ToolExecutionPhase phase,
    String action,
    String description, {
    Map<String, dynamic>? details,
  }) =>
      ToolExecutionMetadata(
        currentPhase: phase,
        auditEntries: [
          ...auditEntries,
          AuditEntry(
            action: action,
            description: description,
            timestamp: DateTime.now(),
            details: details,
          ),
        ],
        durationMs: durationMs,
        recoveryStrategy: recoveryStrategy,
        retryCount: retryCount,
        toolId: toolId,
        executionId: executionId,
      );

  /// Add an audit entry without changing phase.
  ToolExecutionMetadata withAuditEntry(
    String action,
    String description, {
    Map<String, dynamic>? details,
  }) =>
      ToolExecutionMetadata(
        currentPhase: currentPhase,
        auditEntries: [
          ...auditEntries,
          AuditEntry(
            action: action,
            description: description,
            timestamp: DateTime.now(),
            details: details,
          ),
        ],
        durationMs: durationMs,
        recoveryStrategy: recoveryStrategy,
        retryCount: retryCount,
        toolId: toolId,
        executionId: executionId,
      );

  /// Set recovery strategy (returns new metadata).
  ToolExecutionMetadata withRecoveryStrategy(String strategy) =>
      ToolExecutionMetadata(
        currentPhase: currentPhase,
        auditEntries: auditEntries,
        durationMs: durationMs,
        recoveryStrategy: strategy,
        retryCount: retryCount,
        toolId: toolId,
        executionId: executionId,
      );

  /// Increment retry count (returns new metadata).
  ToolExecutionMetadata incrementRetry() =>
      ToolExecutionMetadata(
        currentPhase: currentPhase,
        auditEntries: auditEntries,
        durationMs: durationMs,
        recoveryStrategy: recoveryStrategy,
        retryCount: retryCount + 1,
        toolId: toolId,
        executionId: executionId,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ToolExecutionMetadata &&
          executionId == other.executionId &&
          currentPhase == other.currentPhase;

  @override
  int get hashCode => Object.hash(executionId, currentPhase);

  @override
  String toString() =>
      'ToolExecutionMetadata($toolId, phase: $currentPhase, '
      'entries: ${auditEntries.length}, retries: $retryCount)';
}
