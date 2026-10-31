/// cancellation_token.dart
/// AURA Assistant – Step 22: Tool Execution System
///
/// Cooperative cancellation token for tool execution.
/// Inspired by C# CancellationToken pattern.
/// Tools should check [isCancelled] periodically during execution.
///
/// FAIL CLOSED: if cancellation is in doubt, treat as cancelled.
library;

/// Cooperative cancellation token for tool executions.
///
/// Usage:
/// ```dart
/// final token = CancellationToken();
/// // Pass token to long-running tool
/// // From another isolate/callback:
/// token.cancel();
/// // In tool execution loop:
/// if (token.isCancelled) throw ToolExecutionCancelledException();
/// ```
class CancellationToken {
  bool _isCancelled = false;
  final List<void Function()> _listeners = [];

  /// Whether cancellation has been requested.
  bool get isCancelled => _isCancelled;

  /// Request cancellation. Notifies all listeners.
  /// Idempotent — calling multiple times is safe.
  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;
    for (final listener in _listeners) {
      try {
        listener();
      } catch (_) {
        // Swallow listener errors — cancellation must not throw
      }
    }
    _listeners.clear();
  }

  /// Register a callback to be invoked when cancellation is requested.
  /// If already cancelled, the callback is invoked immediately.
  void onCancel(void Function() callback) {
    if (_isCancelled) {
      callback();
    } else {
      _listeners.add(callback);
    }
  }

  /// Throw if cancelled. Useful for cooperative checks.
  void throwIfCancelled() {
    if (_isCancelled) throw const ToolExecutionCancelledException();
  }

  /// Create an already-cancelled token.
  factory CancellationToken.cancelled() =>
      CancellationToken()..cancel();

  /// Create a token that auto-cancels after the given duration.
  factory CancellationToken.timeout(Duration duration) {
    final token = CancellationToken();
    Future.delayed(duration, () => token.cancel());
    return token;
  }

  /// Combine multiple tokens — cancelled if ANY source token is cancelled.
  static CancellationToken combine(List<CancellationToken> tokens) {
    final combined = CancellationToken();
    for (final token in tokens) {
      token.onCancel(() => combined.cancel());
    }
    return combined;
  }
}

/// Thrown when a cancellation is detected during execution.
class ToolExecutionCancelledException implements Exception {
  final String? message;
  const ToolExecutionCancelledException([this.message]);

  @override
  String toString() =>
      'ToolExecutionCancelledException: ${message ?? "Execution cancelled"}';
}
