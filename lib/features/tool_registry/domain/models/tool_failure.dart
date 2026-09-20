/// tool_failure.dart
/// AURA Assistant – Step 20: Tool Registry & Allowlist
///
/// Failure type for the tool registry & execution subsystem.
/// Follows the MemoryFailure / SecurityFailure pattern:
///   - Phase enum + factory constructors + private subtypes + mixin
///   - FAIL CLOSED: unknown phase → denial
///
/// 9 phases cover the full tool lifecycle:
///   registration → allowlist → security → permission → confirmation →
///   execution → discovery → offline → unknown
library;

import 'package:aura_assistant/core/errors/result.dart';

/// Phases of the tool lifecycle where a failure may occur.
enum ToolFailurePhase {
  /// Failure during tool registration / unregistration.
  registration,

  /// Failure during allowlist check (tool not on allowlist or explicitly denied).
  allowlist,

  /// Failure during security validation (Step 19 integration).
  security,

  /// Failure during permission check (Step 16 integration).
  permission,

  /// Failure during user confirmation (user denied or confirmation unavailable).
  confirmation,

  /// Failure during tool execution (runtime error, timeout, crash).
  execution,

  /// Failure during tool discovery (search / query).
  discovery,

  /// Failure due to offline / connectivity constraints.
  offline,

  /// An unknown or unexpected failure. FAIL CLOSED → treated as denial.
  unknown,
}

/// Mixin for shared fields across all tool failures.
mixin _ToolFailureFields on Object {
  ToolFailurePhase get phase;
  String get message;
  String? get action;
  Object? get cause;
}

/// Private subtype: registration failure.
class _RegistrationFailure with _ToolFailureFields {
  @override
  final ToolFailurePhase phase;
  @override
  final String message;
  @override
  final String? action;
  @override
  final Object? cause;

  _RegistrationFailure({
    required this.phase,
    required this.message,
    this.action,
    this.cause,
  });
}

/// Private subtype: allowlist failure.
class _AllowlistFailure with _ToolFailureFields {
  @override
  final ToolFailurePhase phase;
  @override
  final String message;
  @override
  final String? action;
  @override
  final Object? cause;

  _AllowlistFailure({
    required this.phase,
    required this.message,
    this.action,
    this.cause,
  });
}

/// Private subtype: security failure.
class _SecurityFailure with _ToolFailureFields {
  @override
  final ToolFailurePhase phase;
  @override
  final String message;
  @override
  final String? action;
  @override
  final Object? cause;

  _SecurityFailure({
    required this.phase,
    required this.message,
    this.action,
    this.cause,
  });
}

/// Private subtype: permission failure.
class _PermissionFailure with _ToolFailureFields {
  @override
  final ToolFailurePhase phase;
  @override
  final String message;
  @override
  final String? action;
  @override
  final Object? cause;

  _PermissionFailure({
    required this.phase,
    required this.message,
    this.action,
    this.cause,
  });
}

/// Private subtype: confirmation failure.
class _ConfirmationFailure with _ToolFailureFields {
  @override
  final ToolFailurePhase phase;
  @override
  final String message;
  @override
  final String? action;
  @override
  final Object? cause;

  _ConfirmationFailure({
    required this.phase,
    required this.message,
    this.action,
    this.cause,
  });
}

/// Private subtype: execution failure.
class _ExecutionFailure with _ToolFailureFields {
  @override
  final ToolFailurePhase phase;
  @override
  final String message;
  @override
  final String? action;
  @override
  final Object? cause;

  _ExecutionFailure({
    required this.phase,
    required this.message,
    this.action,
    this.cause,
  });
}

/// Private subtype: discovery failure.
class _DiscoveryFailure with _ToolFailureFields {
  @override
  final ToolFailurePhase phase;
  @override
  final String message;
  @override
  final String? action;
  @override
  final Object? cause;

  _DiscoveryFailure({
    required this.phase,
    required this.message,
    this.action,
    this.cause,
  });
}

/// Private subtype: offline failure.
class _OfflineFailure with _ToolFailureFields {
  @override
  final ToolFailurePhase phase;
  @override
  final String message;
  @override
  final String? action;
  @override
  final Object? cause;

  _OfflineFailure({
    required this.phase,
    required this.message,
    this.action,
    this.cause,
  });
}

/// Private subtype: unknown failure.
class _UnknownFailure with _ToolFailureFields {
  @override
  final ToolFailurePhase phase;
  @override
  final String message;
  @override
  final String? action;
  @override
  final Object? cause;

  _UnknownFailure({
    required this.phase,
    required this.message,
    this.action,
    this.cause,
  });
}

/// Failure type for the tool registry & execution subsystem.
///
/// Follows the MemoryFailure / SecurityFailure pattern: private constructor,
/// factory constructors per phase, private subtypes with shared mixin.
///
/// FAIL CLOSED: any failure during the execution gate results in denial.
class ToolFailure {
  final ToolFailurePhase phase;
  final String message;
  final String? action;
  final Object? cause;

  // Private constructor – only factory constructors may create instances.
  ToolFailure._({
    required this.phase,
    required this.message,
  }) : action = null, cause = null;

  // ─── Factory constructors ───────────────────────────────────────────

  /// Failure during tool registration.
  factory ToolFailure.registration({
    String? toolIdHint,
    String? action,
    Object? cause,
  }) =>
      _RegistrationFailure(
        phase: ToolFailurePhase.registration,
        message: toolIdHint != null
            ? 'Failed to register tool: $toolIdHint'
            : 'Failed to register tool',
        action: action ?? 'retry_registration',
        cause: cause,
      );

  /// Failure during allowlist check.
  /// FAIL CLOSED: tool not on allowlist → denied.
  factory ToolFailure.allowlist({
    required String toolId,
    String? reason,
    String? action,
    Object? cause,
  }) =>
      _AllowlistFailure(
        phase: ToolFailurePhase.allowlist,
        message: reason != null
            ? 'Tool denied by allowlist: $toolId – $reason'
            : 'Tool denied by allowlist: $toolId (not on allowlist)',
        action: action ?? 'add_to_allowlist',
        cause: cause,
      );

  /// Failure during security validation (Step 19 denied the action).
  factory ToolFailure.security({
    required String toolId,
    String? reason,
    String? action,
    Object? cause,
  }) =>
      _SecurityFailure(
        phase: ToolFailurePhase.security,
        message: reason != null
            ? 'Security denied tool execution: $toolId – $reason'
            : 'Security denied tool execution: $toolId',
        action: action ?? 'review_security_policy',
        cause: cause,
      );

  /// Failure during permission check (Step 16: missing permission).
  factory ToolFailure.permission({
    required String toolId,
    required String permissionName,
    String? action,
    Object? cause,
  }) =>
      _PermissionFailure(
        phase: ToolFailurePhase.permission,
        message: 'Missing required permission for tool $toolId: $permissionName',
        action: action ?? 'request_permission',
        cause: cause,
      );

  /// Failure during user confirmation (user denied or timed out).
  factory ToolFailure.confirmation({
    required String toolId,
    String? reason,
    String? action,
    Object? cause,
  }) =>
      _ConfirmationFailure(
        phase: ToolFailurePhase.confirmation,
        message: reason != null
            ? 'User confirmation denied for tool $toolId: $reason'
            : 'User confirmation denied for tool: $toolId',
        action: action ?? 'retry_with_confirmation',
        cause: cause,
      );

  /// Failure during tool execution (runtime error).
  factory ToolFailure.execution({
    required String toolId,
    String? detail,
    String? action,
    Object? cause,
  }) =>
      _ExecutionFailure(
        phase: ToolFailurePhase.execution,
        message: detail != null
            ? 'Tool execution failed: $toolId – $detail'
            : 'Tool execution failed: $toolId',
        action: action ?? 'retry_execution',
        cause: cause,
      );

  /// Failure during tool discovery / search.
  factory ToolFailure.discovery({
    String? queryHint,
    String? action,
    Object? cause,
  }) =>
      _DiscoveryFailure(
        phase: ToolFailurePhase.discovery,
        message: queryHint != null
            ? 'Tool discovery failed for: $queryHint'
            : 'Tool discovery failed',
        action: action ?? 'retry_discovery',
        cause: cause,
      );

  /// Failure due to offline / connectivity constraints.
  factory ToolFailure.offline({
    required String toolId,
    String? detail,
    String? action,
    Object? cause,
  }) =>
      _OfflineFailure(
        phase: ToolFailurePhase.offline,
        message: detail != null
            ? 'Tool unavailable offline: $toolId – $detail'
            : 'Tool unavailable offline: $toolId',
        action: action ?? 'retry_when_online',
        cause: cause,
      );

  /// Unknown / unexpected failure. FAIL CLOSED → treated as denial.
  factory ToolFailure.unknown({
    required String message,
    String? action,
    Object? cause,
  }) =>
      _UnknownFailure(
        phase: ToolFailurePhase.unknown,
        message: message,
        action: action ?? 'unknown',
        cause: cause,
      );

  /// Whether this failure should result in a denial.
  /// FAIL CLOSED: ALL failures result in denial.
  bool get isDenial => true;

  /// Whether this failure is specifically a fail-closed denial
  /// (allowlist, security, permission, or unknown phase).
  bool get isFailClosedDenial =>
      phase == ToolFailurePhase.allowlist ||
      phase == ToolFailurePhase.security ||
      phase == ToolFailurePhase.permission ||
      phase == ToolFailurePhase.unknown;

  @override
  String toString() => 'ToolFailure(phase: $phase, message: $message)';
}

/// Type alias for tool registry results.
typedef ToolResult<T> = Result<T, ToolFailure>;
