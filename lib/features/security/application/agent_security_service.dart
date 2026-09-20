/// agent_security_service.dart
/// AURA Assistant – Step 19: Security & Privacy Hardening
///
/// Application service for agent/tool security.
/// Validates all agent and tool actions against security policy,
/// integrating with Step 16 ActionValidator and ProhibitedActionsRegistry.
///
/// FAIL CLOSED: unknown actions are BLOCKED, not allowed.
library;

import 'package:aura_assistant/core/errors/result.dart';
import '../domain/models/security_config.dart';
import '../domain/models/security_failure.dart';
import '../domain/models/security_verdict.dart';

/// The risk level of an agent/tool action.
enum ActionRiskLevel {
  /// No risk — purely informational/read-only.
  none,

  /// Low risk — limited side effects.
  low,

  /// Medium risk — moderate side effects (e.g., file modification).
  medium,

  /// High risk — significant side effects (e.g., network access, data exfil).
  high,

  /// Critical risk — irreversible or dangerous (e.g., credential access).
  critical,

  /// Unknown risk — FAIL CLOSED: treated as critical.
  unknown,
}

/// Metadata about an agent/tool action for security evaluation.
class ActionMetadata {
  /// The action identifier (tool name, API call, etc.).
  final String actionId;

  /// Human-readable description of the action.
  final String description;

  /// The risk level of the action.
  final ActionRiskLevel riskLevel;

  /// The data categories this action may access.
  final List<SensitiveDataCategory> accessedCategories;

  /// Whether the action requires network access.
  final bool requiresNetwork;

  /// Whether the action modifies persistent state.
  final bool modifiesState;

  /// Whether the action can exfiltrate data.
  final bool canExfiltrateData;

  const ActionMetadata({
    required this.actionId,
    required this.description,
    this.riskLevel = ActionRiskLevel.unknown,
    this.accessedCategories = const [],
    this.requiresNetwork = false,
    this.modifiesState = false,
    this.canExfiltrateData = false,
  });

  /// FAIL CLOSED: unknown risk is treated as critical.
  bool get isDangerous =>
      riskLevel == ActionRiskLevel.critical ||
      riskLevel == ActionRiskLevel.unknown ||
      canExfiltrateData;

  /// Maximum risk level for this action.
  ActionRiskLevel get effectiveRiskLevel =>
      riskLevel == ActionRiskLevel.unknown
          ? ActionRiskLevel.critical
          : riskLevel;
}

/// Abstract application service for agent/tool security.
///
/// Integrates with:
/// - Step 16: ActionValidator, ProhibitedActionsRegistry
/// - Step 19: SecurityPolicy, SecurityConfig
///
/// FAIL CLOSED: any action not explicitly in the allow-list
/// (in strict mode) or in the deny-list (in permissive mode)
/// is treated as denied.
abstract class AgentSecurityService {
  /// Validate an agent/tool action.
  ///
  /// Returns [SecurityVerdict.allowed] only if the action passes
  /// all security checks. FAIL CLOSED: ambiguous → denied.
  Future<SecurityResult<SecurityVerdict>> validateAction(
    String actionId, {
    ActionMetadata? metadata,
    String? content,
    Map<String, String> safeContext = const {},
  });

  /// Register an action as known-safe (allow-list).
  ///
  /// Returns true if registered, false if already exists or invalid.
  bool registerAllowedAction(String actionId, ActionMetadata metadata);

  /// Register an action as known-dangerous (deny-list).
  ///
  /// Returns true if registered, false if already exists or invalid.
  bool registerDeniedAction(String actionId, ActionMetadata metadata);

  /// Get metadata for a known action.
  ActionMetadata? getActionMetadata(String actionId);

  /// Get all allowed actions.
  List<String> get allowedActions;

  /// Get all denied actions.
  List<String> get deniedActions;

  /// Check if an action is in the deny-list.
  bool isActionDenied(String actionId);

  /// Check if an action is in the allow-list.
  bool isActionAllowed(String actionId);

  /// The current agent security mode.
  AgentSecurityMode get currentMode;
}
