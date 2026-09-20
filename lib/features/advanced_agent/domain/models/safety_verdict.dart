/// safety_verdict.dart
/// AURA Assistant – Step 25: Advanced Agent Capabilities
///
/// Safety gate verdict (capability 10: Safety Gate).
/// FAIL-CLOSED: unknown/unavailable → denied.
library;

/// Verdict returned by the safety gate.
enum SafetyVerdictStatus {
  /// Action is permitted.
  allowed,

  /// Action is denied (fail-closed default).
  denied,

  /// Action requires human approval before proceeding.
  requiresApproval,
  ;

  /// FAIL-CLOSED: any unknown name maps to [denied].
  static SafetyVerdictStatus fromName(String name) {
    return SafetyVerdictStatus.values.firstWhere(
      (e) => e.name == name,
      orElse: () => SafetyVerdictStatus.denied,
    );
  }
}

/// Comprehensive safety verdict for an action, tool, or plan step.
class SafetyVerdict {
  final String verdictId;
  final SafetyVerdictStatus status;
  final String? action;
  final String? toolId;
  final String? riskCategory;
  final String rationale;
  final String? mitigation;
  final DateTime evaluatedAt;

  const SafetyVerdict({
    required this.verdictId,
    this.status = SafetyVerdictStatus.denied,
    this.action,
    this.toolId,
    this.riskCategory,
    this.rationale = '',
    this.mitigation,
    required this.evaluatedAt,
  });

  /// Whether the action is allowed to proceed.
  bool get isAllowed => status == SafetyVerdictStatus.allowed;

  /// Whether the action is explicitly denied.
  bool get isDenied => status == SafetyVerdictStatus.denied;

  /// Whether the action requires human approval.
  bool get requiresApproval =>
      status == SafetyVerdictStatus.requiresApproval;

  /// FAIL-CLOSED: factory for denied verdict.
  factory SafetyVerdict.denied({
    required String verdictId,
    String? action,
    String? toolId,
    String? riskCategory,
    String rationale = 'Action denied by safety gate (fail-closed).',
  }) =>
      SafetyVerdict(
        verdictId: verdictId,
        status: SafetyVerdictStatus.denied,
        action: action,
        toolId: toolId,
        riskCategory: riskCategory,
        rationale: rationale,
        evaluatedAt: DateTime.now(),
      );

  /// Factory: explicitly allowed verdict.
  factory SafetyVerdict.allowed({
    required String verdictId,
    String? action,
    String? toolId,
    String rationale = 'Action allowed by safety gate.',
  }) =>
      SafetyVerdict(
        verdictId: verdictId,
        status: SafetyVerdictStatus.allowed,
        action: action,
        toolId: toolId,
        rationale: rationale,
        evaluatedAt: DateTime.now(),
      );

  /// Factory: action requires human approval.
  factory SafetyVerdict.requiresApproval({
    required String verdictId,
    String? action,
    String? toolId,
    String? riskCategory,
    String rationale = 'Action requires human approval.',
    String? mitigation,
  }) =>
      SafetyVerdict(
        verdictId: verdictId,
        status: SafetyVerdictStatus.requiresApproval,
        action: action,
        toolId: toolId,
        riskCategory: riskCategory,
        rationale: rationale,
        mitigation: mitigation,
        evaluatedAt: DateTime.now(),
      );

  /// FAIL-CLOSED: factory for unavailable/unknown state → denied.
  factory SafetyVerdict.unavailable({
    required String verdictId,
    String? action,
    String? toolId,
  }) =>
      SafetyVerdict.denied(
        verdictId: verdictId,
        action: action,
        toolId: toolId,
        rationale: 'Safety gate unavailable — failing closed (denied).',
      );

  /// FAIL-CLOSED: factory for error → denied.
  factory SafetyVerdict.error({
    required String verdictId,
    String? action,
    String? toolId,
    String rationale = 'Safety gate error — failing closed (denied).',
  }) =>
      SafetyVerdict.denied(
        verdictId: verdictId,
        action: action,
        toolId: toolId,
        rationale: rationale,
      );

  SafetyVerdict copyWith({
    String? verdictId,
    SafetyVerdictStatus? status,
    String? action,
    String? toolId,
    String? riskCategory,
    String? rationale,
    String? mitigation,
    DateTime? evaluatedAt,
  }) =>
      SafetyVerdict(
        verdictId: verdictId ?? this.verdictId,
        status: status ?? this.status,
        action: action ?? this.action,
        toolId: toolId ?? this.toolId,
        riskCategory: riskCategory ?? this.riskCategory,
        rationale: rationale ?? this.rationale,
        mitigation: mitigation ?? this.mitigation,
        evaluatedAt: evaluatedAt ?? this.evaluatedAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SafetyVerdict &&
          verdictId == other.verdictId &&
          status == other.status;

  @override
  int get hashCode => Object.hash(verdictId, status);

  @override
  String toString() =>
      'SafetyVerdict(id: $verdictId, status: $status, '
      'action: $action, toolId: $toolId)';
}
