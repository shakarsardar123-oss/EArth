/// permission_security_service.dart
/// AURA Assistant – Step 19: Security & Privacy Hardening
///
/// Application service integrating Step 16 CentralPermissionController
/// with Step 19 security policy.
///
/// FAIL CLOSED: if permission check fails, access is denied.
library;

import 'package:aura_assistant/core/errors/result.dart';
import '../domain/models/security_failure.dart';
import '../domain/models/security_verdict.dart';

/// Security context for a permission request.
class PermissionSecurityContext {
  /// The permission being requested.
  final String permissionId;

  /// The feature requesting the permission.
  final String requestingFeature;

  /// The reason for the request (human-readable, redacted).
  final String reason;

  /// Whether this is a one-time or persistent request.
  final bool isOneTime;

  /// The risk level of granting this permission.
  final PermissionSecurityRisk riskLevel;

  const PermissionSecurityContext({
    required this.permissionId,
    required this.requestingFeature,
    this.reason = '',
    this.isOneTime = false,
    this.riskLevel = PermissionSecurityRisk.unknown,
  });
}

/// Risk level for permission security.
enum PermissionSecurityRisk {
  /// No risk — permission is safe to grant.
  none,

  /// Low risk — permission has limited access.
  low,

  /// Medium risk — permission accesses moderate data.
  medium,

  /// High risk — permission accesses sensitive data.
  high,

  /// Critical risk — permission can exfiltrate data.
  critical,

  /// Unknown risk — FAIL CLOSED: treated as critical.
  unknown,
}

/// Result of a permission security check.
class PermissionSecurityResult {
  /// Whether the permission is allowed.
  final bool isAllowed;

  /// The security verdict.
  final SecurityVerdict verdict;

  /// Additional security conditions (e.g., time-limited, redacted output).
  final List<String> securityConditions;

  const PermissionSecurityResult({
    required this.isAllowed,
    required this.verdict,
    this.securityConditions = const [],
  });

  @override
  String toString() =>
      'PermissionSecurityResult(allowed: \$isAllowed, verdict: \${verdict.displayReason})';
}

/// Abstract application service for permission security.
///
/// Integrates with:
/// - Step 16: CentralPermissionController, DevicePermission, PermissionStatus
/// - Step 19: SecurityPolicy
abstract class PermissionSecurityService {
  /// Check if a permission request is allowed by security policy.
  Future<SecurityResult<PermissionSecurityResult>> checkPermission(
    PermissionSecurityContext context,
  );

  /// Register a security rule for a permission.
  bool registerPermissionRule(
    String permissionId,
    PermissionSecurityRisk riskLevel, {
    List<String> securityConditions = const [],
  });

  /// Get the security risk level for a permission.
  PermissionSecurityRisk getPermissionRisk(String permissionId);

  /// Get all registered permission security rules.
  Map<String, PermissionSecurityRisk> get registeredPermissionRules;
}
