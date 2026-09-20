/// Step 23 — Permission Adapter (WIRED)
///
/// Implements [PermissionRepository] by delegating to the real Step 16
/// [PermissionService], resolving a tool's declared permission requirements
/// to concrete Android [ph.Permission]s via the real [SecurityPolicy], and
/// looking the tool up in the canonical core [ToolRegistry].
///
/// Type conversion happens ONLY at this boundary:
///   toolId (String) → core Tool → List<ToolPermissionRequirement>
///     → List<ph.Permission> (via SecurityPolicy)
///   PermissionService results → domain PermissionVerdict
///
/// FAIL-CLOSED: unknown tool, error, or any ungranted permission → denied.
/// Never fakes a grant.

import 'package:permission_handler/permission_handler.dart' as ph;

import '../../../../core/permissions/permission_service.dart';
import '../../../../core/security/security_policy.dart';
import '../../../../core/tools/tool.dart';
import '../../../../core/tools/tool_registry.dart';
import '../../domain/orchestration_domain.dart';
import '../../../../core/errors/result.dart';

class PermissionAdapter implements PermissionRepository {
  /// The real Step 16 permission service (injected).
  final PermissionService _permissionService;

  /// The real security policy providing ToolPermission → ph.Permission mapping.
  final SecurityPolicy _securityPolicy;

  /// The canonical core tool registry (same one AgentEngine uses).
  final ToolRegistry _registry;

  PermissionAdapter(
    this._permissionService,
    this._securityPolicy,
    this._registry,
  );

  /// Resolve the concrete Android permissions a tool requires.
  /// Returns null if the tool is unknown (FAIL-CLOSED signal to caller).
  List<ph.Permission>? _resolve(String toolId) {
    final Tool? tool = _registry.get(toolId);
    if (tool == null) return null;
    return _securityPolicy.resolvePermissions(
      tool.definition.permissionRequirements,
    );
  }

  @override
  Future<PermissionVerdict> check(String permission, String toolId) async {
    try {
      final required = _resolve(toolId);
      if (required == null) {
        // FAIL-CLOSED: unknown tool → deny.
        return PermissionVerdict.denied(reason: 'Unknown tool: $toolId');
      }
      // A tool with no Android-mapped permissions is implicitly granted.
      if (required.isEmpty) {
        return PermissionVerdict.granted();
      }
      for (final perm in required) {
        final granted = await _permissionService.isPermissionGranted(perm);
        if (!granted) {
          final permanently =
              await _permissionService.isPermissionPermanentlyDenied(perm);
          return PermissionVerdict.denied(
            reason: 'Permission not granted: ${perm.toString()}',
            shouldOpenSettings: permanently,
          );
        }
      }
      return PermissionVerdict.granted();
    } catch (e) {
      // FAIL-CLOSED: any error → deny.
      return PermissionVerdict.denied(reason: 'Permission check error: $e');
    }
  }

  @override
  Future<PermissionVerdict> request(String permission, String toolId) async {
    try {
      final required = _resolve(toolId);
      if (required == null) {
        return PermissionVerdict.denied(reason: 'Unknown tool: $toolId');
      }
      if (required.isEmpty) {
        return PermissionVerdict.granted();
      }
      for (final perm in required) {
        final result = await _permissionService.requestPermission(perm);
        final ok = result.isSuccess && result.getOrElse(() => false);
        if (!ok) {
          final permanently =
              await _permissionService.isPermissionPermanentlyDenied(perm);
          return PermissionVerdict.denied(
            reason: 'Permission request denied: ${perm.toString()}',
            shouldOpenSettings: permanently,
          );
        }
      }
      return PermissionVerdict.granted();
    } catch (e) {
      // FAIL-CLOSED: any error → deny.
      return PermissionVerdict.denied(reason: 'Permission request error: $e');
    }
  }

  @override
  Future<bool> isAvailable() async {
    // The permission service is always constructible; availability is not
    // platform-gated here because per-permission checks already FAIL-CLOSE.
    return true;
  }
}
