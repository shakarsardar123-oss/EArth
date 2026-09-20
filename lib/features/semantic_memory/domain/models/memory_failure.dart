library;

import 'package:aura_assistant/core/errors/result.dart';

typedef MemoryResult<T> = Result<T, MemoryFailure>;

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

sealed class MemoryFailure {
  const MemoryFailure._({
    this.message,
    this.cause,
    this.idHint,
    this.action,
  });

  final String? message;
  final Object? cause;
  final String? idHint;
  final String? action;

  factory MemoryFailure.store({
    String? message,
    Object? cause,
    String? idHint,
    String? action,
  }) =>
      _StoreFailure(message: message, cause: cause, idHint: idHint, action: action);

  factory MemoryFailure.recall({
    String? message,
    Object? cause,
    String? idHint,
    String? action,
  }) =>
      _RecallFailure(message: message, cause: cause, idHint: idHint, action: action);

  factory MemoryFailure.search({
    String? message,
    Object? cause,
    String? idHint,
    String? action,
    String? queryHint,
  }) =>
      _SearchFailure(
        message: message,
        cause: cause,
        idHint: idHint,
        action: action,
        queryHint: queryHint,
      );

  factory MemoryFailure.update({
    String? message,
    Object? cause,
    String? idHint,
    String? action,
  }) =>
      _UpdateFailure(message: message, cause: cause, idHint: idHint, action: action);

  factory MemoryFailure.forget({
    String? message,
    Object? cause,
    String? idHint,
    String? action,
  }) =>
      _ForgettingFailure(message: message, cause: cause, idHint: idHint, action: action);

  factory MemoryFailure.embedding({
    String? message,
    Object? cause,
    String? idHint,
    String? action,
  }) =>
      _EmbeddingFailure(message: message, cause: cause, idHint: idHint, action: action);

  factory MemoryFailure.policy({
    String? message,
    Object? cause,
    String? idHint,
    String? action,
    String? reason,
  }) =>
      _PolicyFailure(
        message: message,
        cause: cause,
        idHint: idHint,
        action: action,
        reason: reason,
      );

  factory MemoryFailure.integration({
    String? message,
    Object? cause,
    String? idHint,
    String? action,
    String? detail,
  }) =>
      _IntegrationFailure(
        message: message,
        cause: cause,
        idHint: idHint,
        action: action,
        detail: detail,
      );

  factory MemoryFailure.unknown({
    String? message,
    Object? cause,
    String? idHint,
    String? action,
  }) =>
      _UnknownFailure(message: message, cause: cause, idHint: idHint, action: action);

  @override
  String toString() =>
      'MemoryFailure(message: $message, cause: $cause, idHint: $idHint, action: $action)';
}

class _StoreFailure extends MemoryFailure {
  const _StoreFailure({super.message, super.cause, super.idHint, super.action}) : super._();
}

class _RecallFailure extends MemoryFailure {
  const _RecallFailure({super.message, super.cause, super.idHint, super.action}) : super._();
}

class _SearchFailure extends MemoryFailure {
  const _SearchFailure({
    super.message,
    super.cause,
    super.idHint,
    super.action,
    this.queryHint,
  }) : super._();

  final String? queryHint;
}

class _UpdateFailure extends MemoryFailure {
  const _UpdateFailure({super.message, super.cause, super.idHint, super.action}) : super._();
}

class _ForgettingFailure extends MemoryFailure {
  const _ForgettingFailure({super.message, super.cause, super.idHint, super.action}) : super._();
}

class _EmbeddingFailure extends MemoryFailure {
  const _EmbeddingFailure({super.message, super.cause, super.idHint, super.action}) : super._();
}

class _PolicyFailure extends MemoryFailure {
  const _PolicyFailure({
    super.message,
    super.cause,
    super.idHint,
    super.action,
    this.reason,
  }) : super._();

  final String? reason;
}

class _IntegrationFailure extends MemoryFailure {
  const _IntegrationFailure({
    super.message,
    super.cause,
    super.idHint,
    super.action,
    this.detail,
  }) : super._();

  final String? detail;
}

class _UnknownFailure extends MemoryFailure {
  const _UnknownFailure({super.message, super.cause, super.idHint, super.action}) : super._();
}
