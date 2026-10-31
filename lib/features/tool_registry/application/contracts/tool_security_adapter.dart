/// tool_security_adapter.dart
/// AURA Assistant – Step 20: Tool Registry & Allowlist
///
/// Adapter that bridges Step 19's AgentSecurityService into the
/// Tool Registry's execution pipeline.
///
/// This adapter translates tool-specific metadata into security
/// action metadata that Step 19 understands, without importing
/// Step 19 types directly (uses string identifiers).
library;

import 'package:texo/core/errors/result.dart';
import 'package:texo/features/tool_registry/domain/models/models.dart';

/// Security verdict after Step 19 validation.
enum ToolSecurityVerdict {
  /// Action is explicitly allowed.
  allowed,

  /// Action is explicitly denied.
  denied,

  /// Fail-closed: could not determine, so deny.
  failClosed,

  /// Unknown state – treated as fail-closed.
  unknown;

  /// Whether this verdict permits execution.
  /// FAIL CLOSED: only [allowed] permits execution.
  bool get permitsExecution => this == ToolSecurityVerdict.allowed;

  /// Whether this is a fail-closed denial.
  bool get isFailClosedDenial =>
      this == ToolSecurityVerdict.failClosed ||
      this == ToolSecurityVerdict.unknown;
}

/// Result of a security check for a tool execution.
class ToolSecurityResult {
  final ToolSecurityVerdict verdict;
  final String? reason;
  final List<String> violatedPolicies;

  const ToolSecurityResult({
    required this.verdict,
    this.reason,
    this.violatedPolicies = const [],
  });

  /// Convenience for an allowed verdict.
  factory ToolSecurityResult.allowed() =>
      const ToolSecurityResult(verdict: ToolSecurityVerdict.allowed);

  /// Convenience for a denied verdict.
  factory ToolSecurityResult.denied({String? reason, List<String>? policies}) =>
      ToolSecurityResult(
        verdict: ToolSecurityVerdict.denied,
        reason: reason,
        violatedPolicies: policies ?? const [],
      );

  /// Convenience for a fail-closed verdict.
  factory ToolSecurityResult.failClosed({String? reason}) =>
      ToolSecurityResult(
        verdict: ToolSecurityVerdict.failClosed,
        reason: reason ?? 'Security check could not complete – fail-closed',
      );

  /// Whether execution is permitted.
  bool get isAllowed => verdict.permitsExecution;
}

/// Abstract interface for the security adapter.
///
/// This abstracts Step 19's AgentSecurityService so the tool
/// registry does not depend on it directly.
abstract class ToolSecurityAdapter {
  /// Check whether a tool execution is allowed by security.
  ///
  /// [toolId] – the tool being executed.
  /// [definition] – the tool's definition (for risk/category metadata).
  /// [metadata] – additional execution metadata (e.g. content being processed).
  ///
  /// Returns [ToolSecurityResult] with the verdict.
  /// FAIL CLOSED: if the security service is unavailable, returns
  /// fail-closed (denied).
  Future<ToolSecurityResult> validateToolExecution({
    required String toolId,
    required ToolDefinition definition,
    Map<String, dynamic>? metadata,
  });

  /// Whether the security service is currently available.
  bool get isAvailable;

  /// Current security mode (as string, to avoid direct coupling).
  ///
  /// Expected values: 'strictAllowlist', 'standard', 'unknown'.
  String get securityMode;
}

