class DefaultToolRecoveryAdapter implements ToolRecoveryAdapter {
  bool _isAvailable = false;

  DefaultToolRecoveryAdapter({bool isAvailable = false})
      : _isAvailable = isAvailable;

  @override
  Future<ToolRecoveryOutcome> recover({
    required String toolId,
    required ToolFailure failure,
    Map<String, dynamic>? context,
  }) async {
    if (!_isAvailable) {
      return ToolRecoveryOutcome.unavailable();
    }

    // Default adapter: map failure phases to simple strategies.
    final phase = failure.phase;

    switch (phase) {
      case ToolFailurePhase.permission:
        // Permission failures: suggest re-requesting permissions.
        return const ToolRecoveryOutcome(
          recovered: false,
          recoveryStrategy: 'requestPermission',
          message: 'Permission failure – try requesting permissions again',
        );

      case ToolFailurePhase.confirmation:
        // Confirmation failures: suggest re-prompting.
        return const ToolRecoveryOutcome(
          recovered: false,
          recoveryStrategy: 'reconfirm',
          message: 'Confirmation denied – user may re-initiate',
        );

      case ToolFailurePhase.execution:
        // Execution failures: suggest retry.
        return const ToolRecoveryOutcome(
          recovered: false,
          recoveryStrategy: 'retry',
          message: 'Execution failed – retry may succeed',
        );

      case ToolFailurePhase.offline:
        // Offline failures: suggest waiting for connectivity.
        return const ToolRecoveryOutcome(
          recovered: false,
          recoveryStrategy: 'waitForConnectivity',
          message: 'Tool unavailable offline – wait for connectivity',
        );

      default:
        // Other phases (allowlist, security, registration, discovery):
        // No automatic recovery possible.
        return ToolRecoveryOutcome.failed(
          message: 'No recovery available for failure phase: ${phase.name}',
        );
    }
  }

  @override
  bool get isAvailable => _isAvailable;

  @override
  List<String> availableStrategies() {
    if (!_isAvailable) return const [];
    return const ['requestPermission', 'reconfirm', 'retry', 'waitForConnectivity'];
  }

  /// Configure availability.
  void setAvailable(bool available) => _isAvailable = available;
}

/// Production adapter that bridges Step 18's RecoveryCoordinator.
///
/// Translates [ToolFailure] into Step 18's error format and
/// invokes the RecoveryCoordinator.
class Step18RecoveryAdapter implements ToolRecoveryAdapter {
  /// The Step 18 RecoveryCoordinator instance.
  ///
  /// Type is dynamic to avoid direct import. Expected to implement:
  ///   recover(context, rawError, action?) -> RecoveryResult<AgentPlan>
  final dynamic _recoveryCoordinator;

  bool _isAvailable;

  Step18RecoveryAdapter({
    required dynamic recoveryCoordinator,
    bool isAvailable = true,
  })  : _recoveryCoordinator = recoveryCoordinator,
        _isAvailable = isAvailable;

  @override
  Future<ToolRecoveryOutcome> recover({
    required String toolId,
    required ToolFailure failure,
    Map<String, dynamic>? context,
  }) async {
    if (!_isAvailable || _recoveryCoordinator == null) {
      return ToolRecoveryOutcome.unavailable();
    }

    try {
      // Build recovery context for Step 18.
      final recoveryContext = {
        'toolId': toolId,
        'failurePhase': failure.phase.name,
        'failureMessage': failure.message,
        'isFailClosedDenial': failure.isFailClosedDenial,
        'isDenial': failure.isDenial,
        ...?context,
      };

      // Call Step 18's recover method.
      final result = await _recoveryCoordinator.recover(
        recoveryContext,
        failure.message,
        action: toolId,
      );

      // Translate Step 18 RecoveryResult.
      final resultStr = result.toString().toLowerCase();
      if (resultStr.contains('success') || resultStr.contains('recovered')) {
        return ToolRecoveryOutcome.success(
          recoveredToolId: toolId,
          strategy: 'step18_recovery',
          message: 'Step 18 recovered tool: $toolId',
        );
      } else {
        return ToolRecoveryOutcome.failed(
          message: 'Step 18 could not recover tool: $toolId',
        );
      }
    } catch (e) {
      return ToolRecoveryOutcome.failed(
        message: 'Step 18 recovery threw: $e',
      );
    }
  }

  @override
  bool get isAvailable => _isAvailable;

  @override
  List<String> availableStrategies() {
    if (!_isAvailable || _recoveryCoordinator == null) return const [];
    try {
      // Try to get strategies from Step 18.
      final strategies = _recoveryCoordinator.availableStrategies;
      if (strategies is List) {
        return strategies.map((s) => s.toString()).toList();
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  /// Update availability.
  void setAvailable(bool available) => _isAvailable = available;
}
