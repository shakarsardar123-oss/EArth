/// Step 23 — Unified Request Context
///
/// Immutable context carried through the entire orchestration lifecycle.
/// Contains ONLY information required to safely coordinate a request.
///
/// FAIL-CLOSED: default values deny/empty everything.
/// Memory failure → null context (safe degradation).
/// Security unknown → denied. Permission unknown → denied.

import 'orchestration_state.dart';
import '../repositories/agent_engine_repository.dart';

class UnifiedRequestContext {
  /// Unique identifier for this request.
  final String requestId;

  /// The raw user request (text or voice transcript).
  final String userRequest;

  /// Primary locale — Kurdish Sorani RTL first: 'ku'.
  final String locale;

  /// The structured intent produced by the AgentEngine understanding phase.
  /// Null means understanding has not yet completed or failed.
  final AgentIntent? intent;

  /// Memory context retrieved from Step 17, if available.
  /// Null means memory was unavailable or lookup was skipped.
  final String? memoryContext;

  /// The tool ID selected after discovery, or null if no tool needed.
  final String? selectedToolId;

  /// Risk level of the selected tool (from Step 20 registry).
  final String? toolRiskLevel;

  /// Whether security (Step 19) cleared this request.
  final bool securityCleared;

  /// Whether permissions (Step 16) were granted.
  final bool permissionGranted;

  /// Whether confirmation (Step 20) was obtained.
  final bool confirmationObtained;

  /// Whether execution (Step 22) succeeded.
  final bool executionSucceeded;

  /// Whether recovery (Step 18) was attempted and its outcome.
  final bool recoveryAttempted;
  final bool recoverySucceeded;

  /// Whether the request was cancelled by the user.
  final bool isCancelled;

  /// Whether the device is currently offline.
  final bool isOffline;

  /// Current orchestration state.
  final OrchestrationState state;

  /// Voice-originated flag — true if request came via STT.
  final bool isVoiceRequest;

  /// Screen/device action flag — true if request involves screen control.
  final bool isScreenAction;

  const UnifiedRequestContext({
    required this.requestId,
    required this.userRequest,
    this.locale = 'ku',
    this.intent,
    this.memoryContext,
    this.selectedToolId,
    this.toolRiskLevel,
    this.securityCleared = false,
    this.permissionGranted = false,
    this.confirmationObtained = false,
    this.executionSucceeded = false,
    this.recoveryAttempted = false,
    this.recoverySucceeded = false,
    this.isCancelled = false,
    this.isOffline = false,
    required this.state,
    this.isVoiceRequest = false,
    this.isScreenAction = false,
  });

  /// Initial context for a new request — FAIL-CLOSED defaults.
  /// securityCleared=false, permissionGranted=false, confirmationObtained=false.
  factory UnifiedRequestContext.initial({
    required String requestId,
    required String userRequest,
    String locale = 'ku',
    bool isOffline = false,
    bool isVoiceRequest = false,
    bool isScreenAction = false,
  }) =>
      UnifiedRequestContext(
        requestId: requestId,
        userRequest: userRequest,
        locale: locale,
        intent: null,
        isOffline: isOffline,
        isVoiceRequest: isVoiceRequest,
        isScreenAction: isScreenAction,
        state: OrchestrationState.initial(requestId),
      );

  /// Immutable copy — returns a new context with updated fields.
  UnifiedRequestContext copyWith({
    AgentIntent? intent,
    String? memoryContext,
    String? selectedToolId,
    String? toolRiskLevel,
    bool? securityCleared,
    bool? permissionGranted,
    bool? confirmationObtained,
    bool? executionSucceeded,
    bool? recoveryAttempted,
    bool? recoverySucceeded,
    bool? isCancelled,
    bool? isOffline,
    OrchestrationState? state,
    bool? isVoiceRequest,
    bool? isScreenAction,
  }) =>
      UnifiedRequestContext(
        requestId: requestId,
        userRequest: userRequest,
        locale: locale,
        intent: intent ?? this.intent,
        memoryContext: memoryContext ?? this.memoryContext,
        selectedToolId: selectedToolId ?? this.selectedToolId,
        toolRiskLevel: toolRiskLevel ?? this.toolRiskLevel,
        securityCleared: securityCleared ?? this.securityCleared,
        permissionGranted: permissionGranted ?? this.permissionGranted,
        confirmationObtained: confirmationObtained ?? this.confirmationObtained,
        executionSucceeded: executionSucceeded ?? this.executionSucceeded,
        recoveryAttempted: recoveryAttempted ?? this.recoveryAttempted,
        recoverySucceeded: recoverySucceeded ?? this.recoverySucceeded,
        isCancelled: isCancelled ?? this.isCancelled,
        isOffline: isOffline ?? this.isOffline,
        state: state ?? this.state,
        isVoiceRequest: isVoiceRequest ?? this.isVoiceRequest,
        isScreenAction: isScreenAction ?? this.isScreenAction,
      );

  /// FAIL-CLOSED gate: returns true only if ALL required gates passed.
  bool get mayExecute =>
      securityCleared &&
      permissionGranted &&
      confirmationObtained &&
      !isCancelled;

  /// Whether memory was available and non-empty.
  bool get hasMemoryContext =>
      memoryContext != null && memoryContext!.isNotEmpty;

  /// Whether a tool was selected.
  bool get hasSelectedTool =>
      selectedToolId != null && selectedToolId!.isNotEmpty;

  @override
  String toString() =>
      'UnifiedRequestContext(requestId: $requestId, locale: $locale, '
      'phase: ${state.phase}, tool: $selectedToolId, '
      'security: $securityCleared, permission: $permissionGranted, '
      'confirmation: $confirmationObtained, cancelled: $isCancelled)';
}
