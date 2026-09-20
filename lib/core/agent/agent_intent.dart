/// Type of action the user wants the agent to perform.
enum IntentActionType {
  /// Looking up information (read-only).
  query,

  /// Performing an action that changes state (sends a message, sets alarm, etc.).
  action,

  /// Controlling a device feature (toggle Wi-Fi, adjust volume, etc.).
  control,

  /// Creating something new (compose email, add contact, etc.).
  create,

  /// Removing or deleting something.
  delete,

  /// The user is just chatting — no tool needed.
  conversation,

  /// Intent is ambiguous and needs clarification.
  ambiguous;

  /// Whether this action type requires tool execution.
  bool get requiresTools =>
      this == IntentActionType.query ||
      this == IntentActionType.action ||
      this == IntentActionType.control ||
      this == IntentActionType.create ||
      this == IntentActionType.delete;
}

/// Parsed user intent — the structured understanding of what the user wants.
///
/// This is the output of the "understand" phase and drives the planning phase.
class AgentIntent {
  const AgentIntent({
    required this.goal,
    this.actionType = IntentActionType.conversation,
    this.entities = const [],
    this.constraints = const [],
    this.toolRequirements = const [],
    this.expectedOutcome,
    this.confirmationNeeded = false,
    this.ambiguityReason,
    this.confidence = 0.0,
    this.originalUtterance,
  });

  /// The high-level goal the user wants to achieve.
  final String goal;

  /// What kind of action this intent represents.
  final IntentActionType actionType;

  /// Named entities extracted from the utterance
  /// (e.g. "جەمال" → contact name, "١٠:٣٠" → time).
  final List<IntentEntity> entities;

  /// Constraints or conditions (e.g. "only if Wi-Fi is on").
  final List<String> constraints;

  /// Tool capabilities required to fulfill this intent.
  final List<String> toolRequirements;

  /// What the user expects to happen.
  final String? expectedOutcome;

  /// Whether this intent needs explicit user confirmation before execution.
  final bool confirmationNeeded;

  /// If the intent is ambiguous, why.
  final String? ambiguityReason;

  /// Confidence score 0.0–1.0.
  final double confidence;

  /// The original user utterance (Kurdish Sorani).
  final String? originalUtterance;

  /// Whether the intent is too ambiguous to plan.
  bool get isAmbiguous =>
      actionType == IntentActionType.ambiguous ||
      confidence < 0.5 ||
      ambiguityReason != null;

  /// Whether this intent can be planned immediately.
  bool get isPlanable =>
      !isAmbiguous && goal.isNotEmpty;

  AgentIntent copyWith({
    String? goal,
    IntentActionType? actionType,
    List<IntentEntity>? entities,
    List<String>? constraints,
    List<String>? toolRequirements,
    String? expectedOutcome,
    bool? confirmationNeeded,
    String? ambiguityReason,
    double? confidence,
    String? originalUtterance,
  }) {
    return AgentIntent(
      goal: goal ?? this.goal,
      actionType: actionType ?? this.actionType,
      entities: entities ?? this.entities,
      constraints: constraints ?? this.constraints,
      toolRequirements: toolRequirements ?? this.toolRequirements,
      expectedOutcome: expectedOutcome ?? this.expectedOutcome,
      confirmationNeeded:
          confirmationNeeded ?? this.confirmationNeeded,
      ambiguityReason: ambiguityReason ?? this.ambiguityReason,
      confidence: confidence ?? this.confidence,
      originalUtterance: originalUtterance ?? this.originalUtterance,
    );
  }

  @override
  String toString() =>
      'AgentIntent(goal: $goal, type: $actionType, confidence: $confidence)';
}

/// A named entity extracted from the user's utterance.
class IntentEntity {
  const IntentEntity({
    required this.name,
    required this.type,
    required this.value,
    this.confidence = 1.0,
  });

  /// The canonical name of the entity (e.g. "contact_name").
  final String name;

  /// The entity type (e.g. "person", "time", "location").
  final String type;

  /// The raw value extracted (e.g. "جەمال").
  final String value;

  /// Extraction confidence 0.0–1.0.
  final double confidence;

  @override
  String toString() => 'IntentEntity($name: $value [$type])';
}
