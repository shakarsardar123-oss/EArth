/// Confirmation guard for tool-level security in AURA.
///
/// Provides per-tool confirmation with action binding (prevents replay attacks),
/// bilingual Kurdish/English context messages, accept/cancel semantics, and
/// timeout-based expiration.
library;

import 'dart:convert';
import 'security_messages.dart';
import '../agent/agent_confirmation_manager.dart';
import '../tools/tool_arguments.dart';

/// State of a tool-level confirmation request.
enum ToolConfirmationState {
  /// No confirmation pending or needed.
  none,

  /// Waiting for user to accept or cancel.
  pending,

  /// User accepted the exact action.
  accepted,

  /// User cancelled the action.
  cancelled,

  /// Confirmation expired (timeout).
  expired;

  /// Whether the confirmation allows execution.
  bool get isAllowed => this == ToolConfirmationState.accepted;

  /// Whether we are waiting for a response.
  bool get isPending => this == ToolConfirmationState.pending;
}

/// A bound confirmation request that ties acceptance to a specific tool+args hash.
///
/// This prevents replay attacks where an attacker might try to reuse a
/// previous confirmation to execute a different action. The [actionHash]
/// is computed from the tool name + sanitized arguments, and only the
/// exact same tool+args combination can be executed after confirmation.
class ToolConfirmationRequest {
  ToolConfirmationRequest({
    required this.toolName,
    required this.arguments,
    required this.riskLevel,
    required this.actionHash,
    required this.message,
    required this.contextDescription,
    this.timeout = const Duration(seconds: 60),
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// The tool name being confirmed.
  final String toolName;

  /// The exact arguments for the tool.
  final Map<String, dynamic> arguments;

  /// Risk level that triggered this confirmation.
  final ToolRiskLevel riskLevel;

  /// Hash binding this confirmation to a specific tool+args combination.
  final String actionHash;

  /// Bilingual message shown to the user.
  final String message;

  /// Additional context description for user awareness.
  final String contextDescription;

  /// Timeout for this confirmation (default 60s).
  final Duration timeout;

  /// When this request was created.
  final DateTime createdAt;

  /// User's decision.
  ToolConfirmationState _state = ToolConfirmationState.pending;

  /// Current state of this confirmation.
  ToolConfirmationState get state => _state;

  /// Whether this confirmation has expired.
  bool get isExpired =>
      DateTime.now().difference(createdAt) > timeout;

  /// Accept this confirmation — binds to the exact action hash.
  void accept() {
    if (isExpired) {
      _state = ToolConfirmationState.expired;
      return;
    }
    _state = ToolConfirmationState.accepted;
  }

  /// Cancel this confirmation.
  void cancel() {
    _state = ToolConfirmationState.cancelled;
  }

  /// Verify that the given tool+args match this confirmation's action hash.
  ///
  /// This prevents replay: even if a user accepted, we verify the exact
  /// same tool+args are being executed, not a different one.
  bool verifyActionHash(String toolName, Map<String, dynamic> arguments) {
    final computedHash = ConfirmationGuard.computeActionHash(
      toolName,
      arguments,
    );
    return computedHash == actionHash;
  }

  @override
  String toString() =>
      'ToolConfirmationRequest($toolName, risk: $riskLevel, '
      'state: $_state, hash: $actionHash)';
}

/// Manages tool-level confirmation with action binding.
///
/// Unlike [AgentConfirmationManager] (plan-level), this guard operates
/// at the individual tool invocation level. Each confirmation is bound
/// to a specific tool+args hash, preventing replay attacks.
///
/// Flow:
/// 1. [requestConfirmation] creates a [ToolConfirmationRequest]
/// 2. User sees bilingual message with action context
/// 3. User accepts → [acceptPending] binds to the action hash
/// 4. [verifyAndExecute] checks the hash matches before allowing execution
class ConfirmationGuard {
  ConfirmationGuard({
    this.messages = const SecurityMessages(),
  });

  /// Security messages provider.
  final SecurityMessages messages;

  /// Currently pending confirmation request.
  ToolConfirmationRequest? _pending;

  /// History of all confirmation requests.
  final List<ToolConfirmationRequest> _history = [];

  /// Maximum number of history entries to retain.
  static const int maxHistory = 100;

  /// The currently pending request.
  ToolConfirmationRequest? get pending => _pending;

  /// All past requests.
  List<ToolConfirmationRequest> get history =>
      List.unmodifiable(_history);

  /// Whether we are waiting for user confirmation.
  bool get isWaitingForConfirmation =>
      _pending?.state.isPending ?? false;

  /// Request confirmation for a tool action.
  ///
  /// Returns the confirmation request for the caller to present to the user.
  /// Returns null if confirmation is not needed (risk level doesn't require it).
  ToolConfirmationRequest? requestConfirmation({
    required String toolName,
    required ToolArguments arguments,
    required ToolRiskLevel riskLevel,
    String? contextDescription,
  }) {
    // Only request confirmation if the risk level requires it.
    if (!riskLevel.requiresConfirmation) {
      return null;
    }

    final argsMap = arguments.values;
    final actionHash = computeActionHash(toolName, argsMap);
    final message = _buildConfirmationMessage(
      toolName,
      argsMap,
      riskLevel,
      contextDescription,
    );

    _pending = ToolConfirmationRequest(
      toolName: toolName,
      arguments: argsMap,
      riskLevel: riskLevel,
      actionHash: actionHash,
      message: message,
      contextDescription: contextDescription ?? '',
    );

    return _pending!;
  }

  /// Accept the pending confirmation.
  ///
  /// The acceptance is bound to the action hash — only the exact
  /// same tool+args can proceed.
  void acceptPending() {
    if (_pending != null) {
      _pending!.accept();
      _addToHistory(_pending!);
      _pending = null;
    }
  }

  /// Cancel the pending confirmation.
  void cancelPending() {
    if (_pending != null) {
      _pending!.cancel();
      _addToHistory(_pending!);
      _pending = null;
    }
  }

  /// Verify that a tool+args combination matches an accepted confirmation.
  ///
  /// This is the core replay-prevention check. Even if confirmation was
  /// accepted, if the tool+args don't match the hash, execution is denied.
  ///
  /// Returns true if:
  /// - The latest history entry was accepted
  /// - Its action hash matches the given tool+args
  /// - It hasn't expired
  bool verifyConfirmation({
    required String toolName,
    required Map<String, dynamic> arguments,
  }) {
    if (_history.isEmpty) return false;

    // Check the most recent entry first.
    final latest = _history.last;
    if (latest.state != ToolConfirmationState.accepted) {
      return false;
    }
    if (latest.isExpired) {
      return false;
    }
    return latest.verifyActionHash(toolName, arguments);
  }

  /// Compute a deterministic hash from tool name + arguments.
  ///
  /// This is NOT a cryptographic hash — it's a deterministic fingerprint
  /// to bind confirmations to specific actions. Uses JSON encoding for
  /// consistency across serializations.
  static String computeActionHash(
    String toolName,
    Map<String, dynamic> arguments,
  ) {
    // Sort keys for deterministic ordering.
    final sortedKeys = arguments.keys.toList()..sort();
    final sortedMap = <String, dynamic>{};
    for (final key in sortedKeys) {
      sortedMap[key] = arguments[key];
    }
    final payload = jsonEncode({
      'tool': toolName,
      'args': sortedMap,
    });
    // Simple deterministic hash (not cryptographic, but sufficient for binding).
    var hash = 0;
    for (final codeUnit in payload.codeUnits) {
      hash = ((hash << 5) - hash + codeUnit) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  /// Clear all state.
  void reset() {
    _pending = null;
    _history.clear();
  }

  // ── Private helpers ──

  void _addToHistory(ToolConfirmationRequest request) {
    _history.add(request);
    // Trim history if too long.
    while (_history.length > maxHistory) {
      _history.removeAt(0);
    }
  }

  String _buildConfirmationMessage(
    String toolName,
    Map<String, dynamic> arguments,
    ToolRiskLevel riskLevel,
    String? contextDescription,
  ) {
    final actionDesc = contextDescription ??
        '$toolName(${_summarizeArgs(arguments)})';

    if (riskLevel == ToolRiskLevel.critical) {
      return messages.confirmationCriticalRisk(actionDesc);
    }

    return messages.confirmationNeeded(toolName, actionDesc);
  }

  String _summarizeArgs(Map<String, dynamic> arguments) {
    if (arguments.isEmpty) return '';
    final entries = arguments.entries
        .map((e) => '${e.key}: ${e.value}')
        .take(3)
        .join(', ');
    return entries.length > 80
        ? '${entries.substring(0, 77)}...'
        : entries;
  }
}
