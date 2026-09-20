/// Central security enforcement gate for the AURA tool framework.
///
/// This gate sits between the ToolRegistry lookup and the actual tool
/// execution, enforcing the full security pipeline:
///
///   Agent → ToolRegistry (allowlist) → ToolSecurityGate → Tool.execute()
///
/// Pipeline steps:
/// 1. Security boundary checks (no shell exec, no intent abuse, etc.)
/// 2. Input validation (package names, settings keys, URL protocols)
/// 3. Permission checks (via PermissionService)
/// 4. Risk assessment and dynamic risk elevation
/// 5. Confirmation guard (for medium/high/critical risk tools)
/// 6. Execution with bound confirmation (prevents replay)
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

import 'permission_state.dart';
import 'security_policy.dart';
import 'security_messages.dart';
import 'confirmation_guard.dart';
import '../permissions/permission_service.dart';
import '../tools/tool.dart';
import '../tools/tool_arguments.dart';
import '../tools/tool_result.dart';
import '../tools/tool_definition.dart';
import '../agent/agent_confirmation_manager.dart';
import '../../core/errors/result.dart';

/// Result of the security gate check.
///
/// Either the tool is allowed to execute, or a specific failure
/// reason is provided with bilingual error messages.
class SecurityGateResult {
  const SecurityGateResult._({
    required this.isAllowed,
    this.permissionCheckResult,
    this.confirmationRequest,
    this.errorCode,
    this.errorMessage,
    this.effectiveRiskLevel,
  });

  /// Tool is allowed to execute — all checks passed.
  factory SecurityGateResult.allowed({
    PermissionCheckResult? permissionCheckResult,
    ToolRiskLevel? effectiveRiskLevel,
  }) =
      _AllowedGateResult;

  /// Permission denied — tool cannot execute.
  factory SecurityGateResult.permissionDenied({
    required PermissionCheckResult permissionCheckResult,
    required String errorMessage,
  }) =
      _PermissionDeniedGateResult;

  /// Confirmation needed before execution.
  factory SecurityGateResult.confirmationNeeded({
    required ToolConfirmationRequest confirmationRequest,
    required ToolRiskLevel effectiveRiskLevel,
  }) =
      _ConfirmationNeededGateResult;

  /// Confirmation was denied — tool cannot execute.
  factory SecurityGateResult.confirmationDenied({
    required String errorMessage,
  }) =
      _ConfirmationDeniedGateResult;

  /// Security boundary violation — tool cannot execute.
  factory SecurityGateResult.boundaryViolation({
    required SecurityBoundaryViolation violation,
  }) =
      _BoundaryViolationGateResult;

  /// Input validation failed — tool cannot execute.
  factory SecurityGateResult.validationFailed({
    required String errorMessage,
    required String errorCode,
  }) =
      _ValidationFailedGateResult;

  /// Platform unsupported — tool cannot execute, but gracefully.
  factory SecurityGateResult.unsupported({
    required String errorMessage,
  }) =
      _UnsupportedGateResult;

  final bool isAllowed;
  final PermissionCheckResult? permissionCheckResult;
  final ToolConfirmationRequest? confirmationRequest;
  final String? errorCode;
  final String? errorMessage;
  final ToolRiskLevel? effectiveRiskLevel;
}

class _AllowedGateResult extends SecurityGateResult {
  _AllowedGateResult({
    PermissionCheckResult? permissionCheckResult,
    ToolRiskLevel? effectiveRiskLevel,
  }) : super._(
         isAllowed: true,
         permissionCheckResult: permissionCheckResult,
         effectiveRiskLevel: effectiveRiskLevel,
       );
}

class _PermissionDeniedGateResult extends SecurityGateResult {
  _PermissionDeniedGateResult({
    required PermissionCheckResult permissionCheckResult,
    required String errorMessage,
  }) : super._(
         isAllowed: false,
         permissionCheckResult: permissionCheckResult,
         errorCode: 'PERMISSION_DENIED',
         errorMessage: errorMessage,
       );
}

class _ConfirmationNeededGateResult extends SecurityGateResult {
  _ConfirmationNeededGateResult({
    required ToolConfirmationRequest confirmationRequest,
    required ToolRiskLevel effectiveRiskLevel,
  }) : super._(
         isAllowed: false,
         confirmationRequest: confirmationRequest,
         effectiveRiskLevel: effectiveRiskLevel,
         errorCode: 'CONFIRMATION_NEEDED',
       );
}

class _ConfirmationDeniedGateResult extends SecurityGateResult {
  _ConfirmationDeniedGateResult({
    required String errorMessage,
  }) : super._(
         isAllowed: false,
         errorCode: 'CONFIRMATION_DENIED',
         errorMessage: errorMessage,
       );
}

class _BoundaryViolationGateResult extends SecurityGateResult {
  _BoundaryViolationGateResult({
    required SecurityBoundaryViolation violation,
  }) : super._(
         isAllowed: false,
         errorCode: 'SECURITY_BOUNDARY',
         errorMessage: violation.message,
       );
}

class _ValidationFailedGateResult extends SecurityGateResult {
  _ValidationFailedGateResult({
    required String errorMessage,
    required String errorCode,
  }) : super._(
         isAllowed: false,
         errorCode: errorCode,
         errorMessage: errorMessage,
       );
}

class _UnsupportedGateResult extends SecurityGateResult {
  _UnsupportedGateResult({
    required String errorMessage,
  }) : super._(
         isAllowed: false,
         errorCode: 'PLATFORM_UNSUPPORTED',
         errorMessage: errorMessage,
       );
}

/// Central security enforcement for the tool execution pipeline.
///
/// Injected between ToolRegistry and tool execution to enforce:
/// - Permission checks (runtime Android permission verification)
/// - Risk-level confirmation (medium/high/critical require user accept)
/// - Input validation (package names, settings keys, URL protocols)
/// - Security boundary enforcement (no shell exec, no intent abuse, etc.)
/// - Replay prevention (confirmation bound to specific tool+args)
class ToolSecurityGate {
  ToolSecurityGate({
    required this.permissionService,
    required this.securityPolicy,
    required this.confirmationGuard,
    SecurityMessages? messages,
  }) : _messages = messages ?? const SecurityMessages();

  final PermissionService permissionService;
  final SecurityPolicy securityPolicy;
  final ConfirmationGuard confirmationGuard;
  final SecurityMessages _messages;

  /// Whether we are currently running on Android.
  bool get isAndroid {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  /// Full security gate check for a tool invocation.
  ///
  /// This is the main entry point called by [AgentExecutor.executeTool()]
  /// AFTER allowlist/validation but BEFORE tool.execute().
  ///
  /// Returns [SecurityGateResult.allowed] if all checks pass,
  /// or a specific failure result indicating why execution is blocked.
  Future<SecurityGateResult> check({
    required Tool tool,
    required ToolArguments arguments,
    String? contextDescription,
    ToolRiskLevel? overriddenRiskLevel,
  }) async {
    final definition = tool.definition;
    final argsMap = arguments.values;

    // ── Step 1: Security boundary checks ──
    final boundaryResult = _checkSecurityBoundaries(tool, argsMap);
    if (boundaryResult != null) return boundaryResult;

    // ── Step 2: Input validation ──
    final validationResult = _validateInputs(tool, argsMap);
    if (validationResult != null) return validationResult;

    // ── Step 3: Permission checks ──
    final permissionResult = await _checkPermissions(definition);
    if (!permissionResult.isAllGranted) {
      // If permissions are unsupported, handle gracefully.
      if (permissionResult.needsGracefulFallback &&
          !permissionResult.canRequestAny) {
        return SecurityGateResult.unsupported(
          errorMessage: _buildPermissionFallbackMessage(permissionResult),
        );
      }
      // If permissions can still be requested, return denial.
      return SecurityGateResult.permissionDenied(
        permissionCheckResult: permissionResult,
        errorMessage: _buildPermissionDeniedMessage(permissionResult),
      );
    }

    // ── Step 4: Risk assessment ──
    final effectiveRisk = overriddenRiskLevel ??
        _computeEffectiveRisk(tool, argsMap);

    // ── Step 5: Confirmation check ──
    if (effectiveRisk.requiresConfirmation) {
      // Check if there's a recent accepted confirmation for this exact action.
      if (confirmationGuard.verifyConfirmation(
        toolName: definition.name,
        arguments: argsMap,
      )) {
        // Confirmation already accepted for this exact action — allow.
        return SecurityGateResult.allowed(
          permissionCheckResult: permissionResult,
          effectiveRiskLevel: effectiveRisk,
        );
      }

      // Need new confirmation.
      final request = confirmationGuard.requestConfirmation(
        toolName: definition.name,
        arguments: arguments,
        riskLevel: effectiveRisk,
        contextDescription: contextDescription,
      );

      if (request != null) {
        return SecurityGateResult.confirmationNeeded(
          confirmationRequest: request,
          effectiveRiskLevel: effectiveRisk,
        );
      }
    }

    // ── All checks passed ──
    return SecurityGateResult.allowed(
      permissionCheckResult: permissionResult,
      effectiveRiskLevel: effectiveRisk,
    );
  }

  /// Check after user confirmation has been provided.
  ///
  /// Call this when the user accepts or cancels the confirmation request.
  /// Returns [SecurityGateResult.allowed] if accepted and verified,
  /// or a denial result if cancelled/expired/invalid.
  SecurityGateResult checkAfterConfirmation({
    required String toolName,
    required Map<String, dynamic> arguments,
  }) {
    if (confirmationGuard.verifyConfirmation(
      toolName: toolName,
      arguments: arguments,
    )) {
      return SecurityGateResult.allowed();
    }
    return SecurityGateResult.confirmationDenied(
      errorMessage: _messages.confirmationDenied,
    );
  }

  // ── Private: Security boundary checks ──

  SecurityGateResult? _checkSecurityBoundaries(
    Tool tool,
    Map<String, dynamic> arguments,
  ) {
    // Check for shell execution attempts.
    if (_containsShellExec(arguments)) {
      return SecurityGateResult.boundaryViolation(
        violation: SecurityBoundaryViolation.shellExec,
      );
    }

    // Check for intent abuse.
    if (_containsIntentAbuse(arguments)) {
      return SecurityGateResult.boundaryViolation(
        violation: SecurityBoundaryViolation.intentAbuse,
      );
    }

    // Check for accessibility abuse.
    if (_containsAccessibilityAbuse(arguments)) {
      return SecurityGateResult.boundaryViolation(
        violation: SecurityBoundaryViolation.accessibilityAbuse,
      );
    }

    return null;
  }

  /// Check arguments for shell execution patterns.
  bool _containsShellExec(Map<String, dynamic> arguments) {
    for (final entry in arguments.entries) {
      if (entry.value is String) {
        final value = (entry.value as String).toLowerCase();
        if (value.contains('sh -c') ||
            value.contains('/bin/sh') ||
            value.contains('/system/bin/sh') ||
            value.contains('exec(') ||
            value.contains('runtime.exec') ||
            value.contains('processbuilder') ||
            value.contains('&& rm ') ||
            value.contains('&& chmod ')) {
          return true;
        }
      }
    }
    return false;
  }

  /// Check arguments for intent abuse patterns.
  bool _containsIntentAbuse(Map<String, dynamic> arguments) {
    for (final entry in arguments.entries) {
      if (entry.value is String) {
        final value = (entry.value as String).toLowerCase();
        if (value.contains('intent{') ||
            value.contains('startactivity') &&
                !value.contains('package:') ||
            value.contains('sendbroadcast') ||
            value.contains('startservice')) {
          return true;
        }
      }
    }
    return false;
  }

  /// Check arguments for accessibility abuse patterns.
  bool _containsAccessibilityAbuse(Map<String, dynamic> arguments) {
    for (final entry in arguments.entries) {
      if (entry.value is String) {
        final value = (entry.value as String).toLowerCase();
        if (value.contains('accessibilityservice') ||
            value.contains('dispatchgesture') ||
            value.contains('performglobalaction')) {
          return true;
        }
      }
    }
    return false;
  }

  // ── Private: Input validation ──

  SecurityGateResult? _validateInputs(
    Tool tool,
    Map<String, dynamic> arguments,
  ) {
    final toolName = tool.definition.name;

    // Validate package names for app_launch tool.
    if (toolName == 'app_launch' && arguments.containsKey('packageName')) {
      final packageName = arguments['packageName'] as String?;
      if (packageName == null ||
          !securityPolicy.isValidPackageName(packageName)) {
        return SecurityGateResult.validationFailed(
          errorMessage: _messages.invalidPackageName,
          errorCode: 'INVALID_PACKAGE_NAME',
        );
      }
    }

    // Validate settings keys for system_settings tool.
    if (toolName == 'system_settings' && arguments.containsKey('setting')) {
      final settingKey = arguments['setting'] as String?;
      if (settingKey == null ||
          !securityPolicy.isValidSettingsKey(settingKey)) {
        return SecurityGateResult.validationFailed(
          errorMessage: _messages.invalidSettingsKey,
          errorCode: 'INVALID_SETTINGS_KEY',
        );
      }
    }

    // Validate URL protocols for url_launch tool.
    if (toolName == 'url_launch' && arguments.containsKey('url')) {
      final url = arguments['url'] as String?;
      if (url == null || !securityPolicy.isAllowedUrlProtocol(url)) {
        return SecurityGateResult.validationFailed(
          errorMessage: _messages.disallowedUrlProtocol,
          errorCode: 'DISALLOWED_URL_PROTOCOL',
        );
      }
    }

    return null;
  }

  // ── Private: Permission checks ──

  Future<PermissionCheckResult> _checkPermissions(
    ToolDefinition definition,
  ) async {
    if (definition.permissionRequirements.isEmpty) {
      return const PermissionCheckResult(
        overallStatus: ToolPermissionStatus.granted,
        permissionStatuses: {},
      );
    }

    final requiredPermissions = securityPolicy.resolvePermissions(
      definition.permissionRequirements,
    );

    if (requiredPermissions.isEmpty) {
      // All permissions are null (implicitly granted or unsupported).
      return const PermissionCheckResult(
        overallStatus: ToolPermissionStatus.granted,
        permissionStatuses: {},
      );
    }

    // If not on Android, all platform-specific permissions are unsupported.
    if (!isAndroid) {
      final unsupportedNames = requiredPermissions
          .map((p) => p.toString())
          .toList();
      return PermissionCheckResult(
        overallStatus: ToolPermissionStatus.unsupported,
        permissionStatuses: {},
        unsupportedPermissions: unsupportedNames,
        messages: [
          _messages.platformFallback,
        ],
      );
    }

    // Check each permission status.
    final statuses = <ToolPermissionStatus, List<String>>{};
    final denied = <String>[];
    final permanentlyDenied = <String>[];
    final unsupported = <String>[];
    final messages = <String>[];

    for (final perm in requiredPermissions) {
      final permName = perm.toString();
      try {
        final isGranted = await permissionService.isPermissionGranted(perm);
        if (isGranted) {
          statuses.putIfAbsent(ToolPermissionStatus.granted, () => [])
              .add(permName);
        } else {
          final isPermanentlyDenied =
              await permissionService.isPermissionPermanentlyDenied(perm);
          if (isPermanentlyDenied) {
            permanentlyDenied.add(permName);
            statuses
                .putIfAbsent(ToolPermissionStatus.permanentlyDenied, () => [])
                .add(permName);
            messages.add(
              _messages.permissionPermanentlyDenied(permName),
            );
          } else {
            denied.add(permName);
            statuses
                .putIfAbsent(ToolPermissionStatus.denied, () => [])
                .add(permName);
            messages.add(_messages.permissionDenied(permName));
          }
        }
      } catch (e) {
        // Permission check failed — treat as unsupported.
        unsupported.add(permName);
        statuses
            .putIfAbsent(ToolPermissionStatus.unsupported, () => [])
            .add(permName);
        messages.add(
          _messages.permissionCheckError(permName, e.toString()),
        );
      }
    }

    // Determine overall status — most restrictive wins.
    ToolPermissionStatus overall;
    if (permanentlyDenied.isNotEmpty) {
      overall = ToolPermissionStatus.permanentlyDenied;
    } else if (denied.isNotEmpty) {
      overall = ToolPermissionStatus.denied;
    } else if (unsupported.isNotEmpty) {
      overall = ToolPermissionStatus.unsupported;
    } else {
      overall = ToolPermissionStatus.granted;
    }

    return PermissionCheckResult(
      overallStatus: overall,
      permissionStatuses: statuses,
      deniedPermissions: denied,
      permanentlyDeniedPermissions: permanentlyDenied,
      unsupportedPermissions: unsupported,
      messages: messages,
    );
  }

  // ── Private: Risk assessment ──

  /// Compute the effective risk level considering dynamic elevation.
  ToolRiskLevel _computeEffectiveRisk(
    Tool tool,
    Map<String, dynamic> arguments,
  ) {
    var risk = tool.definition.riskLevel;

    // Dynamic risk elevation for system_settings tool.
    if (tool.definition.name == 'system_settings' &&
        arguments.containsKey('setting')) {
      final key = arguments['setting'] as String?;
      if (key != null) {
        risk = securityPolicy.elevatedRiskForSettingsKey(key, risk);
      }
    }

    // Dynamic risk elevation for url_launch with sensitive protocols.
    if (tool.definition.name == 'url_launch' &&
        arguments.containsKey('url')) {
      final url = arguments['url'] as String?;
      if (url != null && securityPolicy.isSensitiveUrlProtocol(url)) {
        if (risk.index < ToolRiskLevel.high.index) {
          risk = ToolRiskLevel.high;
        }
      }
    }

    // Dynamic risk elevation for app_launch with sensitive packages.
    if (tool.definition.name == 'app_launch' &&
        arguments.containsKey('packageName')) {
      final packageName = arguments['packageName'] as String?;
      if (packageName != null && securityPolicy.isSensitivePackage(packageName)) {
        if (risk.index < ToolRiskLevel.high.index) {
          risk = ToolRiskLevel.high;
        }
      }
    }

    return risk;
  }

  // ── Private: Message builders ──

  String _buildPermissionDeniedMessage(PermissionCheckResult result) {
    final parts = <String>[
      'ڕێگەپێدان ڕەتکرایەوە / Permission denied',
    ];
    if (result.deniedPermissions.isNotEmpty) {
      parts.add('ڕەتکراوە: ${result.deniedPermissions.join(', ')} / '
          'Denied: ${result.deniedPermissions.join(', ')}');
    }
    return parts.join('. ');
  }

  String _buildPermissionFallbackMessage(PermissionCheckResult result) {
    final parts = <String>[
      _messages.platformFallback,
    ];
    if (result.unsupportedPermissions.isNotEmpty) {
      parts.add('بەردەست نییە: ${result.unsupportedPermissions.join(', ')} / '
          'Unsupported: ${result.unsupportedPermissions.join(', ')}');
    }
    if (result.permanentlyDeniedPermissions.isNotEmpty) {
      parts.add('هەمیشە ڕەتکراوە: '
          '${result.permanentlyDeniedPermissions.join(', ')} / '
          'Permanently denied: '
          '${result.permanentlyDeniedPermissions.join(', ')}');
    }
    return parts.join('. ');
  }
}

/// Convert a [SecurityGateResult] to a [ToolResult].
///
/// Used when the security gate blocks execution — the result
/// carries the error code and bilingual message.
ToolResult securityGateResultToToolResult(SecurityGateResult gateResult) {
  if (gateResult.isAllowed) {
    return const ToolResult.success(null);
  }

  final code = gateResult.errorCode ?? 'SECURITY_GATE_BLOCKED';
  final message = gateResult.errorMessage ?? 'Security gate blocked execution';

  return ToolResult.failure(message, errorCode: code);
}
