/// security_permission_adapter.dart
/// AURA Assistant – Step 19: Security & Privacy Hardening
///
/// Adapter bridging Security feature with Step 16 CentralPermissionController.
/// Ensures all permission requests go through security checks before
/// being forwarded to the permission controller.
///
/// FAIL CLOSED: if security check fails, the permission request is
/// blocked even if the permission controller would allow it.
library;

import 'package:aura_assistant/core/errors/result.dart';
import '../domain/models/security_failure.dart';
import '../domain/models/security_verdict.dart';

/// Security decision for a permission request.
class PermissionSecurityDecision {
  /// Whether the permission request is allowed to proceed.
  final bool isAllowed;

  /// The permission being requested.
  final String permissionId;

  /// Security risk level assigned by the security layer.
  final String securityRiskLevel;

  /// Reason for denial (if denied).
  final String? denialReason;

  /// Whether this denial is fail-closed.
  final bool isFailClosedDenial;

  /// Additional security context to pass to permission controller.
  final Map<String, dynamic> securityContext;

  /// Whether a security audit event should be recorded.
  final bool shouldAudit;

  const PermissionSecurityDecision({
    required this.isAllowed,
    required this.permissionId,
    required this.securityRiskLevel,
    this.denialReason,
    this.isFailClosedDenial = false,
    this.securityContext = const {},
    this.shouldAudit = true,
  });

  /// FAIL CLOSED: denied before reaching permission controller.
  factory PermissionSecurityDecision.failClosedDenial({
    required String permissionId,
    String? reason,
  }) =>
      PermissionSecurityDecision(
        isAllowed: false,
        permissionId: permissionId,
        securityRiskLevel: 'critical',
        denialReason: reason ??
            'Permission blocked by security layer — fail closed',
        isFailClosedDenial: true,
        shouldAudit: true,
      );

  /// Convert to a SecurityVerdict.
  SecurityVerdict get asVerdict {
    if (isAllowed) {
      return SecurityVerdict.allowed(
        action: 'permission:\$permissionId',
        reason: 'Permission passed security check',
      );
    }
    return SecurityVerdict.denied(
      action: 'permission:\$permissionId',
      reason: denialReason ?? 'Permission denied by security',
      category: SensitiveDataCategory.unknown,
    );
  }
}

/// Permission request context with security metadata.
class SecurePermissionRequest {
  /// The permission ID being requested.
  final String permissionId;

  /// The feature requesting the permission.
  final String requestingFeature;

  /// Human-readable reason for the request.
  final String reason;

  /// Whether the request is user-initiated.
  final bool isUserInitiated;

  /// Additional context.
  final Map<String, dynamic> extraContext;

  const SecurePermissionRequest({
    required this.permissionId,
    required this.requestingFeature,
    required this.reason,
    this.isUserInitiated = false,
    this.extraContext = const {},
  });
}

/// Abstract adapter for integrating security with permission system.
///
/// This adapter sits BETWEEN the feature layer and the
/// CentralPermissionController, ensuring security checks run first.
abstract class SecurityPermissionAdapter {
  /// Evaluate a permission request through the security layer.
  /// This runs BEFORE the CentralPermissionController.
  Future<SecurityResult<PermissionSecurityDecision>> evaluatePermissionRequest(
    SecurePermissionRequest request,
  );

  /// Check if a permission is currently allowed by security policy.
  Future<SecurityResult<bool>> isPermissionAllowed(
    String permissionId,
  );

  /// Register a permission rule in the security layer.
  /// This adds security-level restrictions on top of
  /// CentralPermissionController rules.
  Future<SecurityResult<void>> registerPermissionSecurityRule({
    required String permissionId,
    required String riskLevel,
    required bool isDenied,
    String? reason,
  });

  /// Get all security-level permission restrictions.
  Map<String, PermissionSecurityDecision> get permissionSecurityRules;

  /// Remove a security-level permission rule.
  /// FAIL CLOSED: cannot remove rules that are fail-closed.
  Future<SecurityResult<bool>> removePermissionSecurityRule(
    String permissionId,
  );
}
