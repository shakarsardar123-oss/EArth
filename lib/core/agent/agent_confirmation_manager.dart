import 'agent_context.dart';
import 'agent_plan.dart';
import 'agent_intent.dart';

/// State of a pending confirmation request.
class ConfirmationRequest {
  ConfirmationRequest({
    required this.planId,
    required this.message,
    required this.riskLevel,
    this.confirmed,
    this.deniedReason,
  });

  /// The plan awaiting confirmation.
  final String planId;

  /// Message shown to the user (Kurdish Sorani).
  final String message;

  /// How risky the plan is.
  final ToolRiskLevel riskLevel;

  /// User's decision (null = pending).
  bool? confirmed;

  /// If denied, why.
  String? deniedReason;

  /// Whether this request is still pending.
  bool get isPending => confirmed == null;

  /// Accept the confirmation.
  void accept() => confirmed = true;

  /// Deny the confirmation.
  void deny([String? reason]) {
    confirmed = false;
    deniedReason = reason;
  }
}

/// Risk level of a tool action.
enum ToolRiskLevel {
  /// No risk — read-only, no side effects.
  none,

  /// Low risk — minor side effects (e.g. reading contacts).
  low,

  /// Medium risk — user-facing changes (e.g. sending SMS).
  medium,

  /// High risk — irreversible or sensitive (e.g. deleting data, calling).
  high,

  /// Critical — financial or security-critical (not used currently but reserved).
  critical;

  /// Whether this risk level requires user confirmation.
  bool get requiresConfirmation =>
      this == ToolRiskLevel.medium ||
      this == ToolRiskLevel.high ||
      this == ToolRiskLevel.critical;
}

/// Manages user confirmation flow for risky actions.
///
/// Phase 4 confirmation manager:
/// - Pauses execution when confirmation is needed
/// - Stores pending confirmation requests
/// - Allows user to accept/deny
/// - Resumes execution after acceptance
class AgentConfirmationManager {
  /// Currently pending confirmation request.
  ConfirmationRequest? _pending;

  /// History of all confirmation requests.
  final List<ConfirmationRequest> _history = [];

  /// The currently pending request.
  ConfirmationRequest? get pending => _pending;

  /// All past requests.
  List<ConfirmationRequest> get history =>
      List.unmodifiable(_history);

  /// Whether we are waiting for user confirmation.
  bool get isWaitingForConfirmation => _pending?.isPending ?? false;

  /// Determine if a plan needs confirmation and create the request.
  ///
  /// Returns the request if confirmation is needed, null otherwise.
  ConfirmationRequest? requestConfirmationIfNeeded(
    AgentPlan plan,
    AgentIntent intent,
  ) {
    // If intent explicitly requires confirmation, always ask.
    if (intent.confirmationNeeded) {
      return _createRequest(
        plan,
        _buildConfirmationMessage(plan, intent),
        ToolRiskLevel.high,
      );
    }

    // Check if any step in the plan requires confirmation.
    final maxRisk = _maxRiskInPlan(plan);
    if (maxRisk.requiresConfirmation) {
      return _createRequest(
        plan,
        _buildConfirmationMessage(plan, intent),
        maxRisk,
      );
    }

    return null;
  }

  /// User accepts the pending request.
  void acceptPending() {
    if (_pending != null) {
      _pending!.accept();
      _history.add(_pending!);
      _pending = null;
    }
  }

  /// User denies the pending request.
  void denyPending([String? reason]) {
    if (_pending != null) {
      _pending!.deny(reason);
      _history.add(_pending!);
      _pending = null;
    }
  }

  /// Clear the pending request without recording (e.g. if plan is cancelled).
  void cancelPending() {
    _pending = null;
  }

  /// Get the confirmation state for AgentContext.
  ConfirmationState get confirmationState {
    if (_pending == null) return ConfirmationState.none;
    if (_pending!.confirmed == true) return ConfirmationState.approved;
    if (_pending!.confirmed == false) return ConfirmationState.denied;
    return ConfirmationState.pending;
  }

  // ── Private helpers ──

  ConfirmationRequest _createRequest(
    AgentPlan plan,
    String message,
    ToolRiskLevel risk,
  ) {
    _pending = ConfirmationRequest(
      planId: plan.planId,
      message: message,
      riskLevel: risk,
    );
    return _pending!;
  }

  String _buildConfirmationMessage(AgentPlan plan, AgentIntent intent) {
    final stepDescriptions = plan.steps
        .map((s) => '  - ${s.description}')
          .join('\n');
    return 'ئایا ڕێگە دەدەیت ئەم کارانە بکرێت؟\n$stepDescriptions';
  }

  ToolRiskLevel _maxRiskInPlan(AgentPlan plan) {
    // For now, default to the action type of the intent.
    // When tools have explicit risk levels, we'll check those.
    ToolRiskLevel max = ToolRiskLevel.none;
    for (final step in plan.steps) {
      // Heuristic: steps that send/create/delete are higher risk.
      final desc = step.description?.toLowerCase() ?? '';
      if (desc.contains('delete') || desc.contains('call') ||
          desc.contains('send') || desc.contains('بۆ') ||
          desc.contains('ناردن') || desc.contains('پەیام')) {
        if (max.index < ToolRiskLevel.high.index) {
          max = ToolRiskLevel.high;
        }
      } else if (desc.contains('read') || desc.contains('get') ||
          desc.contains('query') || desc.contains('خوێندنەوە')) {
        if (max.index < ToolRiskLevel.low.index) {
          max = ToolRiskLevel.low;
        }
      } else {
        if (max.index < ToolRiskLevel.medium.index) {
          max = ToolRiskLevel.medium;
        }
      }
    }
    return max;
  }
}
