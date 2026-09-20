/// Immutable state model for the assistant integration feature.
///
/// Follows the project convention: single immutable class with
/// [copyWith] and `clear*` boolean flags for nullable fields.
/// The overall [AssistantLifecycle] enum captures the user-facing
/// state machine.
library;

import '../entities/assistant_status.dart';
import '../entities/assistant_invocation.dart';

/// User-facing lifecycle of the assistant integration.
enum AssistantLifecycle {
  /// Not yet checked / unknown.
  uninitialized,

  /// Currently checking whether the platform supports assistant role.
  checking,

  /// Platform supports it, but AURA is not the default assistant.
  available,

  /// Currently requesting the user to set AURA as default
  /// (system settings UI should be visible).
  requesting,

  /// AURA is the default assistant and ready for invocation.
  active,

  /// A recent invocation is being processed.
  invoked,

  /// The user cancelled the default-assistant request.
  cancelled,

  /// An error occurred during the lifecycle.
  failed,

  /// The platform does not support the assistant role.
  unsupported,
}

/// Immutable state snapshot for the assistant integration feature.
class AssistantState {
  /// Where we are in the assistant lifecycle.
  final AssistantLifecycle lifecycle;

  /// Most recent assistant status (platform capability info).
  final AssistantStatus status;

  /// The most recent invocation payload, if any.
  final AssistantInvocation? currentInvocation;

  /// Error message when [lifecycle] is [AssistantLifecycle.failed].
  final String? errorMessage;

  /// Timestamp of the last state transition.
  final DateTime updatedAt;

  const AssistantState({
    this.lifecycle = AssistantLifecycle.uninitialized,
    this.status = const AssistantStatus(),
    this.currentInvocation,
    this.errorMessage,
    required this.updatedAt,
  });

  /// Convenience: is AURA the default assistant?
  bool get isDefaultAssistant => lifecycle == AssistantLifecycle.active;

  /// Convenience: is an invocation in progress?
  bool get isInvoked => lifecycle == AssistantLifecycle.invoked;

  /// Convenience: can the user request default-assistant status?
  bool get canRequestDefault => lifecycle == AssistantLifecycle.available;

  /// Convenience: is the feature in an error state?
  bool get hasError => lifecycle == AssistantLifecycle.failed;

  AssistantState copyWith({
    AssistantLifecycle? lifecycle,
    AssistantStatus? status,
    AssistantInvocation? currentInvocation,
    bool clearCurrentInvocation = false,
    String? errorMessage,
    bool clearErrorMessage = false,
    DateTime? updatedAt,
  }) {
    return AssistantState(
      lifecycle: lifecycle ?? this.lifecycle,
      status: status ?? this.status,
      currentInvocation: clearCurrentInvocation
          ? null
          : (currentInvocation ?? this.currentInvocation),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssistantState &&
          lifecycle == other.lifecycle &&
          status == other.status &&
          currentInvocation == other.currentInvocation &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode =>
      Object.hash(lifecycle, status, currentInvocation, errorMessage);

  @override
  String toString() =>
      'AssistantState(lifecycle: $lifecycle, '
      'status: $status, '
      'invocation: $currentInvocation, '
      'error: $errorMessage)';
}
