/// Bridges [ToolSecurityGate] confirmation requests to the UI.
///
/// The agent executor calls [SecurityConfirmationController.request] when a
/// medium/high/critical risk tool needs explicit user approval. The controller
/// exposes the pending request as state so a host widget can show a dialog,
/// and completes the future with the user's decision.
///
/// Nothing is auto-approved: if no UI resolves the request within the
/// request timeout, it resolves to `false` (denied).
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/security/confirmation_guard.dart';

/// Holds the currently pending tool confirmation request, if any.
class SecurityConfirmationController
    extends StateNotifier<ToolConfirmationRequest?> {
  SecurityConfirmationController() : super(null);

  Completer<bool>? _completer;
  Timer? _timeoutTimer;

  /// Ask the user to confirm [request]. Returns the user's decision.
  ///
  /// A second concurrent request is denied immediately rather than
  /// replacing (and thereby silently approving) the first one.
  Future<bool> request(ToolConfirmationRequest request) {
    if (_completer != null && !_completer!.isCompleted) {
      return Future.value(false);
    }
    final completer = Completer<bool>();
    _completer = completer;
    state = request;
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(request.timeout, () => _resolve(false));
    return completer.future;
  }

  /// User approved the pending action.
  void approve() => _resolve(true);

  /// User rejected the pending action (also used for dismissal).
  void reject() => _resolve(false);

  void _resolve(bool accepted) {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    final completer = _completer;
    _completer = null;
    state = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete(accepted);
    }
  }

  @override
  void dispose() {
    _resolve(false);
    super.dispose();
  }
}

/// Provider for the security confirmation controller.
final securityConfirmationProvider = StateNotifierProvider<
    SecurityConfirmationController, ToolConfirmationRequest?>((ref) {
  return SecurityConfirmationController();
});
