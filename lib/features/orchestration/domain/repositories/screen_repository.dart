import '../../../../core/errors/result.dart';
/// Step 23 — Screen/Device Repository Interface
///
/// Contract for the Step 14/22 screen and device control adapter.
/// Do not implement a second screen-control engine — delegate to existing systems.

abstract class ScreenRepository {
  /// Execute a screen/device action.
  /// Returns ScreenActionResult. Default/unknown = failed.
  Future<ScreenActionResult> executeAction(String action, Map<String, dynamic> parameters);

  /// Whether the screen control subsystem is available.
  Future<bool> isAvailable();
}

/// Screen action result — FAIL-CLOSED by default.
class ScreenActionResult {
  final bool succeeded;
  final String? resultData;
  final String? errorMessage;

  const ScreenActionResult({
    this.succeeded = false,
    this.resultData,
    this.errorMessage,
  });

  factory ScreenActionResult.success({String? resultData}) =>
      ScreenActionResult(succeeded: true, resultData: resultData);

  factory ScreenActionResult.failed({String? errorMessage}) =>
      ScreenActionResult(errorMessage: errorMessage);
}
