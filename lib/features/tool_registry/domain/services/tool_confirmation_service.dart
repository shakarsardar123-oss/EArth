/// tool_confirmation_service.dart
/// AURA Assistant – Step 20: Tool Registry & Allowlist
///
/// Abstract service for managing user confirmation before tool execution.
///
/// The confirmation service determines whether a tool requires user
/// confirmation (based on [ConfirmationPolicy]) and presents the
/// confirmation request to the user.
///
/// FAIL CLOSED: if confirmation status is ambiguous → denied.
library;

import 'package:aura_assistant/core/errors/result.dart';
import 'package:aura_assistant/features/tool_registry/domain/models/models.dart';

/// Result of a confirmation request.
enum ConfirmationResult {
  /// User explicitly confirmed.
  confirmed,

  /// User explicitly denied.
  denied,

  /// Confirmation timed out. FAIL CLOSED → treated as denied.
  timedOut,

  /// Confirmation could not be presented (e.g. UI not available).
  /// FAIL CLOSED → treated as denied.
  unavailable,

  /// Result unknown. FAIL CLOSED → treated as denied.
  unknown,
}

/// Extension for [ConfirmationResult].
extension ConfirmationResultX on ConfirmationResult {
  /// Whether this result means the user approved execution.
  /// FAIL CLOSED: only [confirmed] is approval.
  bool get isApproved => this == ConfirmationResult.confirmed;

  /// Whether this result means execution should be denied.
  /// FAIL CLOSED: anything other than [confirmed] → denied.
  bool get isDenied => !isApproved;
}

/// Abstract service for requesting user confirmation.
///
/// Concrete implementation in infrastructure layer (UI integration).
abstract class ToolConfirmationService {
  /// Request user confirmation for a tool execution.
  ///
  /// The [definition] provides details about the tool for the
  /// confirmation dialog. The [params] describe what the tool will do.
  ///
  /// Returns [ConfirmationResult.confirmed] if the user approves,
  /// or a denial result otherwise. FAIL CLOSED: timeout/unavailable = denied.
  Future<ConfirmationResult> requestConfirmation({
    required ToolDefinition definition,
    required Map<String, dynamic> params,
    String? reason,
    Duration? timeout,
  });

  /// Whether confirmation is currently available (UI is present).
  bool get isAvailable;
}
