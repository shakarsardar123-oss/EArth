/// memory_failure.dart
/// AURA Assistant – Step 17: Semantic Memory
library;

import 'package:texo/core/errors/result.dart';

/// Phases of the semantic memory lifecycle where a failure may occur.
enum MemoryFailurePhase {
  store,
  recall,
  search,
  update,
  forget,
  embedding,
  policy,
  integration,
  unknown,
}

/// Mixin for shared fields across all memory failures.
mixin _MemoryFailureFields on Object {
  MemoryFailurePhase get phase;
  String get message;
  String? get action;
  Object? get cause;
}

/// Private subtype: store failure.
class _StoreFailure extends MemoryFailure {
  _StoreFailure({
    required MemoryFailurePhase phase,
    required String message,
    String? action,
    Object? cause,
  }) : super._(phase: phase, message: message, action: action, cause: cause);
}

/// Private subtype: recall failure.
class _RecallFailure extends MemoryFailure {
  _RecallFailure({
    required MemoryFailurePhase phase,
    required String message,
    String? action,
    Object? cause,
  }) : super._(phase: phase, message: message, action: action, cause: cause);
}

/// Private subtype: search failure.
class _SearchFailure extends MemoryFailure {
  _SearchFailure({
    required MemoryFailurePhase phase,
    required String message,
    String? action,
    Object? cause,
  }) : super._(phase: phase, message: message, action: action, cause: cause);
}

/// Private subtype: update failure.
class _UpdateFailure extends MemoryFailure {
  _UpdateFailure({
    required MemoryFailurePhase phase,
    required String message,
    String? action,
    Object? cause,
  }) : super._(phase: phase, message: message, action: action, cause: cause);
}

/// Private subtype: forget failure.
class _ForgettingFailure extends MemoryFailure {
  _ForgettingFailure({
    required MemoryFailurePhase phase,
    required String message,
    String? action,
    Object? cause,
  }) : super._(phase: phase, message: message, action: action, cause: cause);
}

/// Private subtype: embedding failure.
class _EmbeddingFailure extends MemoryFailure {
  _EmbeddingFailure({
    required MemoryFailurePhase phase,
    required String message,
    String? action,
    Object? cause,
  }) : super._(phase: phase, message: message, action: action, cause: cause);
}

/// Private subtype: policy failure.
class _PolicyFailure extends MemoryFailure {
  _PolicyFailure({
    required MemoryFailurePhase phase,
    required String message,
    String? action,
    Object? cause,
  }) : super._(phase: phase, message: message, action: action, cause: cause);
}

/// Private subtype: integration failure.
class _IntegrationFailure extends MemoryFailure {
  _IntegrationFailure({
    required MemoryFailurePhase phase,
    required String message,
    String? action,
    Object? cause,
  }) : super._(phase: phase, message: message, action: action, cause: cause);
}

/// Private subtype: unknown failure.
class _UnknownFailure extends MemoryFailure {
  _UnknownFailure({
    required MemoryFailurePhase phase,
    required String message,
    String? action,
    Object? cause,
  }) : super._(phase: phase, message: message, action: action, cause: cause);
}

/// Failure type for the semantic memory subsystem.
class MemoryFailure {
  final MemoryFailurePhase phase;
  final String message;
  final String? action;
  final Object? cause;

  MemoryFailure._({
    required this.phase,
    required this.message,
    this.action,
    this.cause,
  });

  factory MemoryFailure.store({
    String? contentHint,
    String? action,
    Object? cause,
  }) =>
      _StoreFailure(
        phase: MemoryFailurePhase.store,
        message: contentHint != null
            ? 'Failed to store memory: $contentHint'
            : 'Failed to store memory',
        action: action ?? 'retry_store',
        cause: cause,
      );

  factory MemoryFailure.recall({
    String? queryHint,
    String? action,
    Object? cause,
  }) =>
      _RecallFailure(
        phase: MemoryFailurePhase.recall,
        message: queryHint != null
            ? 'Failed to recall memory for: $queryHint'
            : 'Failed to recall memory',
        action: action ?? 'retry_recall',
        cause: cause,
      );

  factory MemoryFailure.search({
    String? queryHint,
    String? action,
    Object? cause,
  }) =>
      _SearchFailure(
        phase: MemoryFailurePhase.search,
        message: queryHint != null
            ? 'Failed to search memories for: $queryHint'
            : 'Failed to search memories',
        action: action ?? 'retry_search',
        cause: cause,
      );

  factory MemoryFailure.update({
    String? idHint,
    String? action,
    Object? cause,
  }) =>
      _UpdateFailure(
        phase: MemoryFailurePhase.update,
        message: idHint != null
            ? 'Failed to update memory: $idHint'
            : 'Failed to update memory',
        action: action ?? 'retry_update',
        cause: cause,
      );

  factory MemoryFailure.forget({
    String? idHint,
    String? action,
    Object? cause,
  }) =>
      _ForgettingFailure(
        phase: MemoryFailurePhase.forget,
        message: idHint != null
            ? 'Failed to forget memory: $idHint'
            : 'Failed to forget memory',
        action: action ?? 'retry_forget',
        cause: cause,
      );

  factory MemoryFailure.embedding({
    String? action,
    Object? cause,
  }) =>
      _EmbeddingFailure(
        phase: MemoryFailurePhase.embedding,
        message: 'Failed to compute embedding',
        action: action ?? 'retry_embedding',
        cause: cause,
      );

  factory MemoryFailure.policy({
    required String reason,
    String? action,
    Object? cause,
  }) =>
      _PolicyFailure(
        phase: MemoryFailurePhase.policy,
        message: 'Memory rejected by policy: $reason',
        action: action ?? 'review_content',
        cause: cause,
      );

  factory MemoryFailure.integration({
    String? detail,
    String? action,
    Object? cause,
  }) =>
      _IntegrationFailure(
        phase: MemoryFailurePhase.integration,
        message: detail != null
            ? 'Memory integration failed: $detail'
            : 'Memory integration failed',
        action: action ?? 'retry_integration',
        cause: cause,
      );

  factory MemoryFailure.unknown({
    required String message,
    String? action,
    Object? cause,
  }) =>
      _UnknownFailure(
        phase: MemoryFailurePhase.unknown,
        message: message,
        action: action ?? 'unknown',
        cause: cause,
      );

  @override
  String toString() => 'MemoryFailure(phase: $phase, message: $message)';
}

/// Type alias for semantic memory results.
typedef MemoryResult<T> = Result<T, MemoryFailure>;
