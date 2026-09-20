/// Step 23 — Security Adapter (WIRED, boundary enforcement)
///
/// Implements [SecurityRepository] by delegating to the real Step 19
/// [SecurityPolicy] (security-boundary enforcement) and the canonical core
/// [ToolRegistry] allowlist. It does NOT duplicate the permission or
/// confirmation stages — those are separate orchestration phases wired to
/// [PermissionService] and [ConfirmationGuard] respectively. This adapter
/// covers the security-boundary + allowlist portion of [ToolSecurityGate]'s
/// pipeline, reusing the SAME [SecurityPolicy] object.
///
/// Agent-generated actions are treated exactly like user actions.
///
/// FAIL-CLOSED: unknown/disallowed tool, any boundary violation, or any
/// error → denied.

import '../../../../core/security/security_policy.dart';
import '../../../../core/tools/tool.dart';
import '../../../../core/tools/tool_registry.dart';
import '../../domain/orchestration_domain.dart';

class SecurityAdapter implements SecurityRepository {
  /// The real Step 19 security policy (injected, never re-created).
  final SecurityPolicy _securityPolicy;

  /// The canonical core tool registry (same one AgentEngine uses).
  final ToolRegistry _registry;

  SecurityAdapter(this._securityPolicy, this._registry);

  @override
  Future<SecurityVerdict> check(
    String action,
    String toolId,
    String riskLevel,
  ) async {
    try {
      // Allowlist boundary: an unknown or disallowed tool is denied.
      final Tool? tool = _registry.get(toolId);
      if (tool == null) {
        return SecurityVerdict.denied(
          reason: 'Unknown tool: $toolId',
          policyId: 'allowlist',
        );
      }
      if (!_registry.isAllowed(tool.name)) {
        return SecurityVerdict.denied(
          reason: 'Tool not allowed by registry allowlist: $toolId',
          policyId: 'allowlist',
        );
      }

      // Security-boundary enforcement via the real SecurityPolicy.
      // No structured arguments are available at this orchestration
      // boundary (parameters are supplied at execution time and re-checked
      // by ToolSecurityGate inside the execution engine), so no boundary
      // flags are asserted here; any violation surfaced by the policy denies.
      final violations = _securityPolicy.checkSecurityBoundaries();
      if (violations.isNotEmpty) {
        return SecurityVerdict.denied(
          reason: 'Security boundary violation: '
              '${violations.map((v) => v.name).join(', ')}',
          policyId: 'security_boundary',
        );
      }

      return SecurityVerdict.allowed(policyId: 'security_boundary');
    } catch (e) {
      // FAIL-CLOSED: any error → deny.
      return SecurityVerdict.denied(reason: 'Security check error: $e');
    }
  }

  @override
  Future<bool> isAvailable() async => true;
}
