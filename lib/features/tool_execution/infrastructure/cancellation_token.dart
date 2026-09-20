/// cancellation_token.dart
/// AURA Assistant – Step 22: Tool Execution System
///
/// Cancellation token for cooperative execution cancellation.
/// CancellationToken.cancel() takes NO arguments.
///
/// FAIL CLOSED: cancellation is irreversible once triggered.
library;

import 'package:meta/meta.dart';
import '../domain/models/exceptions.dart';

/// Cooperative cancellation token for tool execution.
@immutable
class CancellationToken {
  /// Whether cancellation has been requested.
  final bool isCancelled;

  const CancellationToken({this.isCancelled = false});

  /// Request cancellation. Returns a new cancelled token.
  /// Takes NO arguments — cancellation reason is tracked
  /// in ToolExecutionContext, not here.
  CancellationToken cancel() => const CancellationToken(isCancelled: true);

  /// Throw [ToolExecutionCancelledException] if cancelled.
  void throwIfCancelled(String toolId) {
    if (isCancelled) {
      throw ToolExecutionCancelledException(
        'Execution cancelled via token',
        toolId: toolId,
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CancellationToken && isCancelled == other.isCancelled;

  @override
  int get hashCode => isCancelled.hashCode;

  @override
  String toString() =>
      'CancellationToken(cancelled: $isCancelled)';
}
