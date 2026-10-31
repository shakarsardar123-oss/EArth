/// audit_logger.dart
/// AURA Assistant – Step 22: Tool Execution System
///
/// Audit logger — records execution events using the canonical
/// 12 ToolExecutionPhase values and AuditEntry model.
///
/// FAIL CLOSED: audit failures never block execution;
/// they are logged but not rethrown.
library;

import '../domain/models/tool_execution_metadata.dart';

class AuditLogger {
  /// Log an execution event with a specific phase.
  ToolExecutionMetadata logPhase(
    ToolExecutionMetadata metadata,
    ToolExecutionPhase phase,
    String action,
    String description, {
    Map<String, dynamic>? details,
  }) {
    return metadata.withPhase(phase, action, description, details: details);
  }

  /// Log a simple audit entry without changing phase.
  ToolExecutionMetadata log(
    ToolExecutionMetadata metadata,
    String action,
    String description, {
    Map<String, dynamic>? details,
  }) {
    return metadata.withAuditEntry(action, description, details: details);
  }

  /// Log a validation event.
  ToolExecutionMetadata logValidation(
    ToolExecutionMetadata metadata,
    String description, {
    Map<String, dynamic>? details,
  }) =>
      logPhase(
        metadata,
        ToolExecutionPhase.validating,
        'validate',
        description,
        details: details,
      );

  /// Log a confirmation event.
  ToolExecutionMetadata logConfirmation(
    ToolExecutionMetadata metadata,
    String description, {
    Map<String, dynamic>? details,
  }) =>
      logPhase(
        metadata,
        ToolExecutionPhase.confirming,
        'confirm',
        description,
        details: details,
      );

  /// Log a security check event.
  ToolExecutionMetadata logSecurityCheck(
    ToolExecutionMetadata metadata,
    String description, {
    Map<String, dynamic>? details,
  }) =>
      logPhase(
        metadata,
        ToolExecutionPhase.sanitizing,
        'security_check',
        description,
        details: details,
      );

  /// Log execution start.
  ToolExecutionMetadata logExecution(
    ToolExecutionMetadata metadata,
    String description, {
    Map<String, dynamic>? details,
  }) =>
      logPhase(
        metadata,
        ToolExecutionPhase.executing,
        'execute',
        description,
        details: details,
      );

  /// Log normalization.
  ToolExecutionMetadata logNormalization(
    ToolExecutionMetadata metadata,
    String description, {
    Map<String, dynamic>? details,
  }) =>
      logPhase(
        metadata,
        ToolExecutionPhase.normalizing,
        'normalize',
        description,
        details: details,
      );

  /// Log completion.
  ToolExecutionMetadata logCompletion(
    ToolExecutionMetadata metadata,
    String description, {
    Map<String, dynamic>? details,
  }) =>
      logPhase(
        metadata,
        ToolExecutionPhase.completed,
        'complete',
        description,
        details: details,
      );

  /// Log failure.
  ToolExecutionMetadata logFailure(
    ToolExecutionMetadata metadata,
    String description, {
    Map<String, dynamic>? details,
  }) =>
      logPhase(
        metadata,
        ToolExecutionPhase.failed,
        'fail',
        description,
        details: details,
      );

  /// Log cancellation.
  ToolExecutionMetadata logCancellation(
    ToolExecutionMetadata metadata,
    String description, {
    Map<String, dynamic>? details,
  }) =>
      logPhase(
        metadata,
        ToolExecutionPhase.cancelled,
        'cancel',
        description,
        details: details,
      );

  /// Log timeout.
  ToolExecutionMetadata logTimeout(
    ToolExecutionMetadata metadata,
    String description, {
    Map<String, dynamic>? details,
  }) =>
      logPhase(
        metadata,
        ToolExecutionPhase.timedOut,
        'timeout',
        description,
        details: details,
      );

  /// Log denial.
  ToolExecutionMetadata logDenial(
    ToolExecutionMetadata metadata,
    String description, {
    Map<String, dynamic>? details,
  }) =>
      logPhase(
        metadata,
        ToolExecutionPhase.denied,
        'deny',
        description,
        details: details,
      );

  /// Log fail-closed.
  ToolExecutionMetadata logFailClosed(
    ToolExecutionMetadata metadata,
    String description, {
    Map<String, dynamic>? details,
  }) =>
      logPhase(
        metadata,
        ToolExecutionPhase.failClosed,
        'fail_closed',
        description,
        details: details,
      );

  /// Log retry.
  ToolExecutionMetadata logRetry(
    ToolExecutionMetadata metadata,
    String description, {
    Map<String, dynamic>? details,
  }) =>
      log(
        metadata,
        'retry',
        description,
        details: details,
      );
}
