/// Step 23 — Confirmation Adapter (WIRED)
///
/// Implements [ConfirmationRepository] by delegating risk-classification to
/// the real core [ToolRiskLevel] semantics and the real Step 20
/// [ConfirmationGuard]. It never invents its own risk policy.
///
/// Behaviour:
///   • risk that does NOT require confirmation (none / low) → auto-approve.
///   • risk that DOES require confirmation (medium / high / critical) → a
///     bound confirmation request is raised on the real ConfirmationGuard,
///     but because this repository call is non-interactive (no user
///     accept/cancel channel at the adapter boundary), it FAIL-CLOSES to a
///     denied verdict with mode requireConfirmation. The interactive accept
///     path is handled by the presentation layer + ToolSecurityGate during
///     execution, never silently auto-approved here.
///
/// Type conversion happens ONLY at this boundary:
///   riskLevel (String) → core ToolRiskLevel;
///   guard outcome → domain ConfirmationVerdict.
///
/// FAIL-CLOSED: unknown risk string → treated as high; error → denyAll.

import '../../../../core/agent/agent_confirmation_manager.dart';
import '../../../../core/security/confirmation_guard.dart';
import '../../../../core/tools/tool_arguments.dart';
import '../../domain/orchestration_domain.dart';

class ConfirmationAdapter implements ConfirmationRepository {
  /// The real Step 20 confirmation guard (injected).
  final ConfirmationGuard _guard;

  ConfirmationAdapter(this._guard);

  /// Map an orchestration risk String to the core [ToolRiskLevel].
  /// FAIL-CLOSED: any unrecognised value elevates to high.
  ToolRiskLevel _toRisk(String riskLevel) {
    switch (riskLevel.toLowerCase()) {
      case 'none':
        return ToolRiskLevel.none;
      case 'low':
        return ToolRiskLevel.low;
      case 'medium':
        return ToolRiskLevel.medium;
      case 'high':
        return ToolRiskLevel.high;
      case 'critical':
        return ToolRiskLevel.critical;
      default:
        return ToolRiskLevel.high;
    }
  }

  @override
  Future<ConfirmationVerdict> checkAndObtain({
    required String toolId,
    required String riskLevel,
    required String userRequest,
  }) async {
    try {
      final risk = _toRisk(riskLevel);

      // Delegate the risk decision to the real core semantics.
      if (!risk.requiresConfirmation) {
        // AUTO_APPROVE_WARNING: only reached for none/low risk, which the
        // core ToolRiskLevel contract explicitly does not require confirming.
        return ConfirmationVerdict.granted(mode: ConfirmationMode.autoApprove);
      }

      // Engage the real guard to raise a bound confirmation request.
      // (Replay-protected by tool+args hash inside the guard.)
      _guard.requestConfirmation(
        toolName: toolId,
        arguments: const ToolArguments({}),
        riskLevel: risk,
        contextDescription: userRequest,
      );

      // Non-interactive boundary: confirmation is required but cannot be
      // obtained here → FAIL-CLOSED denial. The interactive accept happens
      // in the presentation layer / execution gate.
      return ConfirmationVerdict(
        obtained: false,
        mode: ConfirmationMode.requireConfirmation,
        reason: 'Confirmation required for $riskLevel-risk tool "$toolId" '
            'but not yet obtained',
      );
    } catch (e) {
      // FAIL-CLOSED: error → denyAll.
      return ConfirmationVerdict.denied(reason: 'Confirmation error: $e');
    }
  }

  @override
  Future<bool> isAvailable() async => true;
}
