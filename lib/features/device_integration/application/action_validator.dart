/// action_validator.dart
///
/// Validates a [DeviceAction] through the structural → security → permission
/// pipeline before execution.
///
/// RECOVERED in P1-RECOVERY step R2 from the behaviour pinned by
/// `test/features/device_integration/action_validator_test.dart`.
library;

import '../domain/entities/device_action.dart';
import '../domain/models/device_integration_failure.dart';
import '../domain/models/permission_status.dart';
import '../domain/models/security_verdict.dart';
import '../../../core/errors/result.dart';

/// Validates a [DeviceAction] against structural, security, and permission
/// requirements before it reaches the executor.
class ActionValidator {
  ActionValidator({required this.permissionManager});

  final PermissionManager permissionManager;

  /// Full validation pipeline:
  /// 1. Structural check via [DeviceAction.isValid]
  /// 2. Security check via [checkSecurity]
  /// 3. Permission check via [PermissionManager.checkAll]
  ///
  /// Returns the action on success, or a [DeviceIntegrationFailure] on any
  /// failure.
  Future<Result<DeviceAction, DeviceIntegrationFailure>> validate(
      DeviceAction action) async {
    // 1. Structural
    if (!action.isValid) {
      return Result.failure(
        DeviceIntegrationFailure.validation(
          'Action structurally invalid: ${action.type.name}',
          action: action,
        ),
      );
    }

    // 2. Security
    final securityVerdict = checkSecurity(action);
    if (securityVerdict.isDenied) {
      return Result.failure(
        DeviceIntegrationFailure.security(
          securityVerdict.reason ?? 'Action denied by security policy',
          action: action,
        ),
      );
    }

    // 3. Permissions
    final permResult = await permissionManager.checkAll();
    if (!permResult.allGranted) {
      return Result.failure(
        DeviceIntegrationFailure.permission(
          'Missing permissions: ${permResult.denied.map((p) => p.name).join(', ')}',
          action: action,
        ),
      );
    }

    return Result.success(action);
  }

  /// Check whether the action passes security policy.
  ///
  /// Delegates to [ProhibitedActionsRegistry] for target-label and
  /// action-name checks.
  static SecurityVerdict checkSecurity(DeviceAction action) {
    // Check target label
    final targetLabel = action.targetLabel;
    if (targetLabel != null &&
        _isProhibitedTargetLabel(targetLabel)) {
      return SecurityVerdict.denied(
        'Prohibited target label: $targetLabel',
        rule: 'target_keyword',
      );
    }

    // Check action name
    if (ProhibitedActionsRegistry.isProhibitedActionName(action.type.name)) {
      return SecurityVerdict.denied(
        'Prohibited action type: ${action.type.name}',
        rule: 'action_type',
      );
    }

    return SecurityVerdict.allowed('No policy violation');
  }

  /// Whether the given action-type name is prohibited.
  static bool isProhibitedActionName(String name) =>
      ProhibitedActionsRegistry.isProhibitedActionName(name);

  /// Whether the given target label contains a prohibited keyword.
  static bool _isProhibitedTargetLabel(String label) {
    final lower = label.toLowerCase();
    for (final keyword in ProhibitedActionsRegistry.prohibitedTargetKeywords) {
      if (lower.contains(keyword)) return true;
    }
    return false;
  }
}
