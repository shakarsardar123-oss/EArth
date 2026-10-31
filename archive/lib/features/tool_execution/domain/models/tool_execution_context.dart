/// tool_execution_context.dart
/// AURA Assistant – Step 22: Tool Execution System
///
/// Execution context carried through every tool invocation.
/// Extends Step 20's context model with cancellation, timeout,
/// caller identity, and retry linkage to Step 18.
///
/// FAIL CLOSED: missing context fields default to restrictive values.
library;

import 'package:meta/meta.dart';
import 'exceptions.dart';

/// Immutable execution context for every tool invocation.
///
/// Provides the full environment a tool needs: who called it,
/// what memory context is available, whether cancellation is
/// pending, timeout limits, and retry policy linkage.
@immutable
class ToolExecutionContext {
  // ─── Identity ───────────────────────────────────────────────────

  /// Unique identifier for this execution invocation.
  final String executionId;

  /// The tool being executed.
  final String toolId;

  /// Who or what initiated this execution (user, agent, system, voice).
  final String caller;

  // ─── Memory / Semantic ─────────────────────────────────────────

  /// Memory context to inject into tool execution (from Step 17).
  /// Null means no memory enrichment.
  final String? memoryContext;

  // ─── Cancellation & Timeout ─────────────────────────────────────

  /// Whether cancellation has been requested.
  final bool isCancelled;

  /// Maximum execution duration in milliseconds (0 = no timeout).
  final int timeoutMs;

  // ─── Retry linkage (Step 18) ─────────────────────────────────────

  /// Current retry attempt number (0 = first attempt).
  final int retryAttempt;

  /// Maximum retries allowed for this execution.
  final int maxRetries;

  // ─── Security (Step 19) ──────────────────────────────────────────

  /// Whether the execution has been pre-authorized by security.
  final bool securityCleared;

  /// The security verdict reason (if any).
  final String? securityReason;

  // ─── Presentation ────────────────────────────────────────────────

  /// Whether to show confirmation before execution.
  final bool requiresConfirmation;

  /// Whether this is a background execution.
  final bool isBackground;

  /// Locale for localized tool responses (defaults to Kurdish Sorani).
  final String locale;

  /// Whether the user explicitly denied confirmation.
  /// FAIL CLOSED: if true, execution must not proceed.
  final bool confirmationDenied;

  /// Timestamp of execution start.
  final DateTime startedAt;

  const ToolExecutionContext({
    required this.executionId,
    required this.toolId,
    this.caller = 'user',
    this.memoryContext,
    this.isCancelled = false,
    this.timeoutMs = 30000,
    this.retryAttempt = 0,
    this.maxRetries = 3,
    this.securityCleared = false,
    this.securityReason,
    this.requiresConfirmation = false,
    this.isBackground = false,
    this.locale = 'ku',
    this.confirmationDenied = false,
    DateTime? startedAt,
  }) : startedAt = startedAt ?? DateTime.now();

  /// Whether this execution can proceed (not cancelled, security cleared,
  /// not confirmation-denied).
  bool get canProceed =>
      !isCancelled && securityCleared && !confirmationDenied;

  /// Whether this is the first attempt.
  bool get isFirstAttempt => retryAttempt == 0;

  /// Whether retries are still available.
  bool get canRetry => retryAttempt < maxRetries;

  /// Whether a timeout is configured.
  bool get hasTimeout => timeoutMs > 0;

  /// Elapsed duration since execution started.
  Duration get elapsed => DateTime.now().difference(startedAt);

  /// Whether the execution has exceeded its timeout.
  bool get isTimedOut =>
      hasTimeout && elapsed.inMilliseconds > timeoutMs;

  /// Throw [ToolExecutionCancelledException] if this context is cancelled.
  ///
  /// FAIL CLOSED: also throws if confirmation was denied.
  void throwIfCancelled() {
    if (isCancelled) {
      throw ToolExecutionCancelledException(
        'Execution cancelled',
        toolId: toolId,
        executionId: executionId,
      );
    }
    if (confirmationDenied) {
      throw ToolExecutionCancelledException(
        'Confirmation denied — execution blocked',
        toolId: toolId,
        executionId: executionId,
      );
    }
  }

  /// Copy with cancellation requested.
  ToolExecutionContext cancel() => copyWith(isCancelled: true);

  /// Copy with incremented retry attempt.
  ToolExecutionContext incrementRetry() => copyWith(
        retryAttempt: retryAttempt + 1,
        startedAt: DateTime.now(),
      );

  /// Copy with security clearance.
  ToolExecutionContext withSecurityClearance({
    required String reason,
  }) =>
      copyWith(
        securityCleared: true,
        securityReason: reason,
      );

  /// Copy with confirmation denied.
  ToolExecutionContext withConfirmationDenied() =>
      copyWith(confirmationDenied: true);

  ToolExecutionContext copyWith({
    String? executionId,
    String? toolId,
    String? caller,
    String? memoryContext,
    bool? isCancelled,
    int? timeoutMs,
    int? retryAttempt,
    int? maxRetries,
    bool? securityCleared,
    String? securityReason,
    bool? requiresConfirmation,
    bool? isBackground,
    String? locale,
    bool? confirmationDenied,
    DateTime? startedAt,
  }) =>
      ToolExecutionContext(
        executionId: executionId ?? this.executionId,
        toolId: toolId ?? this.toolId,
        caller: caller ?? this.caller,
        memoryContext: memoryContext ?? this.memoryContext,
        isCancelled: isCancelled ?? this.isCancelled,
        timeoutMs: timeoutMs ?? this.timeoutMs,
        retryAttempt: retryAttempt ?? this.retryAttempt,
        maxRetries: maxRetries ?? this.maxRetries,
        securityCleared: securityCleared ?? this.securityCleared,
        securityReason: securityReason ?? this.securityReason,
        requiresConfirmation: requiresConfirmation ?? this.requiresConfirmation,
        isBackground: isBackground ?? this.isBackground,
        locale: locale ?? this.locale,
        confirmationDenied: confirmationDenied ?? this.confirmationDenied,
        startedAt: startedAt ?? this.startedAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ToolExecutionContext &&
          executionId == other.executionId &&
          toolId == other.toolId &&
          caller == other.caller &&
          isCancelled == other.isCancelled &&
          retryAttempt == other.retryAttempt &&
          securityCleared == other.securityCleared &&
          confirmationDenied == other.confirmationDenied;

  @override
  int get hashCode => Object.hash(
        executionId,
        toolId,
        caller,
        isCancelled,
        retryAttempt,
        securityCleared,
        confirmationDenied,
      );

  @override
  String toString() =>
      'ToolExecutionContext(id: $executionId, tool: $toolId, '
      'caller: $caller, cancelled: $isCancelled, '
      'confirmationDenied: $confirmationDenied, '
      'retry: $retryAttempt/$maxRetries)';
}
