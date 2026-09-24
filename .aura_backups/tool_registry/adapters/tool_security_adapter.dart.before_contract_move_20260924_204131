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

import 'package:aura_assistant/core/errors/result.dart';
import 'package:aura_assistant/features/tool_registry/domain/models/models.dart';

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

/// Default implementation that fails closed when no real
/// security service is available.
///
/// In production, replace with [Step19SecurityAdapter] that
/// wraps the real AgentSecurityService.
class DefaultToolSecurityAdapter implements ToolSecurityAdapter {
  bool _isAvailable = false;
  String _securityMode = 'unknown';

  DefaultToolSecurityAdapter({
    bool isAvailable = false,
    String securityMode = 'unknown',
  bool defaultDenyAll = true,
  })  : _isAvailable = isAvailable,
        _securityMode = securityMode,
        _defaultDenyAll = defaultDenyAll;

  final bool _defaultDenyAll;

  @override
  Future<ToolSecurityResult> validateToolExecution({
    required String toolId,
    required ToolDefinition definition,
    Map<String, dynamic>? metadata,
  }) async {
    // FAIL CLOSED: if security service is unavailable, deny.
    if (!_isAvailable) {
      return ToolSecurityResult.failClosed(
        reason: 'Security service unavailable – fail-closed deny for tool: '
            '$toolId',
      );
    }

    // If default-deny-all is set, deny everything unless explicitly allowed.
    if (_defaultDenyAll) {
      return ToolSecurityResult.denied(
        reason: 'Default deny-all policy – tool: $toolId',
      );
    }

    // Otherwise, basic risk-based check.
    if (definition.isDangerous) {
      return ToolSecurityResult.denied(
        reason: 'Tool $toolId is classified as dangerous '
            '(risk: ${definition.effectiveRiskLevel.name})',
      );
    }

    if (definition.accessesSensitiveData) {
      return ToolSecurityResult.denied(
        reason: 'Tool $toolId accesses sensitive data '
            '(categories: ${definition.accessedCategories.join(", ")})',
      );
    }

    return ToolSecurityResult.allowed();
  }

  @override
  bool get isAvailable => _isAvailable;

  @override
  String get securityMode => _securityMode;

  /// Configure availability (for testing or live binding).
  void setAvailable(bool available) => _isAvailable = available;

  /// Configure security mode.
  void setSecurityMode(String mode) => _securityMode = mode;
}

/// Production adapter that bridges Step 19's AgentSecurityService.
///
/// This class translates [ToolDefinition] fields into
/// [ActionMetadata] that Step 19 understands, using string
/// identifiers to avoid direct import coupling.
///
/// Usage:
/// ```dart
/// final adapter = Step19SecurityAdapter(
///   securityService: agentSecurityService,
/// );
/// ```
class Step19SecurityAdapter implements ToolSecurityAdapter {
  /// The Step 19 security service instance.
  ///
  /// Type is dynamic to avoid direct import. Expected to implement:
  ///   validateAction(actionId, metadata?, content?, safeContext?)
  ///     -> SecurityVerdict (allowed/denied/failClosed)
  final dynamic _securityService;

  /// Whether the service is available.
  bool _isAvailable;

  Step19SecurityAdapter({
    required dynamic securityService,
    bool isAvailable = true,
  })  : _securityService = securityService,
        _isAvailable = isAvailable;

  @override
  Future<ToolSecurityResult> validateToolExecution({
    required String toolId,
    required ToolDefinition definition,
    Map<String, dynamic>? metadata,
  }) async {
    // FAIL CLOSED: if service is unavailable, deny.
    if (!_isAvailable || _securityService == null) {
      return ToolSecurityResult.failClosed(
        reason: 'Step 19 security service unavailable – '
            'fail-closed deny for tool: $toolId',
      );
    }

    try {
      // Translate ToolDefinition to Step 19's ActionMetadata.
      final actionMetadata = {
        'actionId': toolId,
        'riskLevel': definition.effectiveRiskLevel.name,
        'accessedCategories': definition.accessedCategories,
        'isDangerous': definition.isDangerous,
        'effectiveRiskLevel': definition.effectiveRiskLevel.name,
      };

      // Call Step 19's validateAction.
      // The result is expected to have a .verdict field or
      // be one of: allowed, denied, failClosed.
      final result = await _securityService.validateAction(
        toolId,
        metadata: actionMetadata,
        content: metadata?['content'],
        safeContext: metadata?['safeContext'] ?? false,
      );

      // Translate Step 19 verdict to ToolSecurityVerdict.
      final verdictString = result.toString().toLowerCase();
      if (verdictString.contains('allowed') ||
          verdictString == 'securityverdict.allowed') {
        return ToolSecurityResult.allowed();
      } else if (verdictString.contains('failclosed') ||
          verdictString.contains('fail_closed')) {
        return ToolSecurityResult.failClosed(
          reason: 'Step 19 fail-closed for tool: $toolId',
        );
      } else {
        return ToolSecurityResult.denied(
          reason: 'Step 19 denied for tool: $toolId',
        );
      }
    } catch (e) {
      // FAIL CLOSED: any exception means deny.
      return ToolSecurityResult.failClosed(
        reason: 'Step 19 security check threw exception: $e – '
            'fail-closed deny for tool: $toolId',
      );
    }
  }

  @override
  bool get isAvailable => _isAvailable;

  @override
  String get securityMode {
    if (_securityService == null) return 'unknown';
    try {
      // Try to get the security mode from Step 19.
      final mode = _securityService.securityMode;
      if (mode is String) return mode;
      // If it's an enum, get its name.
      return mode.toString().split('.').last;
    } catch (_) {
      return 'unknown';
    }
  }

  /// Update availability (e.g., based on Step 19 state changes).
  void setAvailable(bool available) => _isAvailable = available;
}
