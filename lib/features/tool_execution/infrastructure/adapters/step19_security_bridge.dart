/// step19_security_bridge.dart
/// AURA Assistant – Step 22: Tool Execution System
///
/// Bridge between Step 22 (Tool Execution) and Step 19 (Security).
///
/// Adapts Step 19's SecurityVerdict, SensitiveDataCategory,
/// and security adapter to work with Step 22's execution pipeline.
///
/// Step 19 API:
///   SecurityVerdict: .allowed(reason, action), .denied(reason, action, category), .failClosed(reason, action)
///   SensitiveDataCategory: 18 values
///   SecurityAdapter.check(definition) → SecurityVerdict (NOT validateToolExecution())
///
/// FAIL CLOSED: any bridge failure, unknown state, or exception
/// results in a fail-closed security denial.
library;

/// Security verdict from Step 19, adapted for Step 22.
///
/// Wraps Step 19's SecurityVerdict into a structure compatible
/// with Step 22's execution pipeline.
class BridgedSecurityVerdict {
  final bool allowed;
  final String? reason;
  final String? action;
  final String? category;
  final bool isFailClosed;

  const BridgedSecurityVerdict._({
    required this.allowed,
    this.reason,
    this.action,
    this.category,
    this.isFailClosed = false,
  });

  /// Display-safe reason for the verdict.
  String get displayReason => reason ??
      (allowed ? 'Allowed' : (isFailClosed ? 'Fail-closed denial' : 'Denied'));

  /// Whether this is a fail-closed denial (most restrictive).
  bool get isFailClosedDenial => !allowed && isFailClosed;

  /// Create an allowed verdict.
  factory BridgedSecurityVerdict.allowed({
    String? reason,
    String? action,
  }) =>
      BridgedSecurityVerdict._(
        allowed: true,
        reason: reason ?? 'Security check passed',
        action: action,
      );

  /// Create a denied verdict.
  factory BridgedSecurityVerdict.denied({
    String? reason,
    String? action,
    String? category,
  }) =>
      BridgedSecurityVerdict._(
        allowed: false,
        reason: reason ?? 'Security check denied',
        action: action,
        category: category,
        isFailClosed: false,
      );

  /// Create a fail-closed verdict (most restrictive denial).
  factory BridgedSecurityVerdict.failClosed({
    String? reason,
    String? action,
  }) =>
      BridgedSecurityVerdict._(
        allowed: false,
        reason: reason ?? 'Fail-closed: security state unknown',
        action: action,
        isFailClosed: true,
      );
}

/// Bridge between Step 22 and Step 19's security system.
///
/// Adapts Step 19's SecurityVerdict pattern for Step 22's needs.
/// All methods are FAIL CLOSED — any error results in denial.
class Step19SecurityBridge {
  /// Tools that have been explicitly allowed by security.
  final Set<String> _allowedTools = {};

  /// Tools that have been explicitly denied by security.
  final Set<String> _deniedTools = {};

  /// Tools requiring elevated permissions.
  final Map<String, Set<String>> _toolPermissions = {};

  /// Sensitive data categories detected per tool.
  final Map<String, Set<SensitiveDataCategoryBridge>> _sensitiveCategories = {};

  Step19SecurityBridge({
    Set<String>? preApprovedTools,
    Set<String>? preDeniedTools,
    Map<String, Set<String>>? toolPermissions,
  }) {
    if (preApprovedTools != null) _allowedTools.addAll(preApprovedTools);
    if (preDeniedTools != null) _deniedTools.addAll(preDeniedTools);
    if (toolPermissions != null) _toolPermissions.addAll(toolPermissions);
  }

  // ─── Security checks ───────────────────────────────────────────────

  /// Check if a tool is allowed by security.
  ///
  /// Maps to Step 19's SecurityAdapter.check(definition) → SecurityVerdict.
  BridgedSecurityVerdict checkTool(String toolId) {
    try {
      // If explicitly denied, return denied
      if (_deniedTools.contains(toolId)) {
        return BridgedSecurityVerdict.denied(
          reason: 'Tool is on the denied list',
          action: 'execute:$toolId',
        );
      }

      // If explicitly allowed, return allowed
      if (_allowedTools.contains(toolId)) {
        return BridgedSecurityVerdict.allowed(
          reason: 'Tool is on the approved list',
          action: 'execute:$toolId',
        );
      }

      // If permissions are required, check if they can be satisfied
      final requiredPerms = _toolPermissions[toolId];
      if (requiredPerms != null && requiredPerms.isNotEmpty) {
        // Default: deny if permissions are required but not verified
        // In production, this would call Step 19's SecurityAdapter
        return BridgedSecurityVerdict.denied(
          reason: 'Tool requires permissions: ${requiredPerms.join(", ")}',
          action: 'execute:$toolId',
          category: 'permission_required',
        );
      }

      // Unknown tool — FAIL CLOSED
      return BridgedSecurityVerdict.failClosed(
        reason: 'Tool security status unknown — fail closed',
        action: 'execute:$toolId',
      );
    } catch (e) {
      return BridgedSecurityVerdict.failClosed(
        reason: 'Security check error: $e',
        action: 'execute:$toolId',
      );
    }
  }

  /// Check security for a tool with specific parameters.
  ///
  /// Additional parameter-level security checks.
  BridgedSecurityVerdict checkToolWithParams(
    String toolId,
    Map<String, dynamic> params,
  ) {
    // First, check the tool itself
    final toolVerdict = checkTool(toolId);
    if (!toolVerdict.allowed) return toolVerdict;

    // Then check parameters for sensitive data
    final sensitiveCategories = _detectSensitiveData(params);
    if (sensitiveCategories.isNotEmpty) {
      _sensitiveCategories[toolId] = sensitiveCategories;

      // Some tools are allowed to handle sensitive data
      if (_allowedTools.contains(toolId)) {
        return BridgedSecurityVerdict.allowed(
          reason: 'Tool approved for sensitive data handling',
          action: 'execute:$toolId',
        );
      }

      return BridgedSecurityVerdict.denied(
        reason: 'Parameters contain sensitive data: '
            '${sensitiveCategories.map((c) => c.name).join(", ")}',
        action: 'execute:$toolId',
        category: 'sensitive_data',
      );
    }

    return toolVerdict;
  }

  /// Check if a specific permission is granted for a tool.
  ///
  /// Maps to Step 19's check(permId) pattern.
  bool checkPermission(String toolId, String permissionId) {
    try {
      final requiredPerms = _toolPermissions[toolId];
      if (requiredPerms == null) {
        // No permissions required — FAIL CLOSED for unknown
        return false;
      }
      return requiredPerms.contains(permissionId);
    } catch (e) {
      return false; // FAIL CLOSED
    }
  }

  /// Get sensitive data categories detected for a tool.
  Set<SensitiveDataCategoryBridge> getSensitiveCategories(String toolId) =>
      _sensitiveCategories[toolId] ?? {};

  // ─── Registration methods ──────────────────────────────────────────

  /// Pre-approve a tool (e.g., safe built-in tools).
  void approveTool(String toolId) => _allowedTools.add(toolId);

  /// Deny a tool explicitly.
  void denyTool(String toolId) => _deniedTools.add(toolId);

  /// Set required permissions for a tool.
  void setToolPermissions(String toolId, Set<String> permissions) =>
      _toolPermissions[toolId] = permissions;

  // ─── Sensitive data detection ──────────────────────────────────────

  /// Detect sensitive data categories in parameters.
  ///
  /// Maps to Step 19's SensitiveDataCategory (18 values).
  Set<SensitiveDataCategoryBridge> _detectSensitiveData(
    Map<String, dynamic> params,
  ) {
    final categories = <SensitiveDataCategoryBridge>{};

    _walkParams(params, '', (key, value) {
      final keyLower = key.toLowerCase();

      if (keyLower.contains('password') || keyLower.contains('pwd')) {
        categories.add(SensitiveDataCategoryBridge.authentication);
      }
      if (keyLower.contains('token') || keyLower.contains('session')) {
        categories.add(SensitiveDataCategoryBridge.authentication);
      }
      if (keyLower.contains('email') || keyLower.contains('mail')) {
        categories.add(SensitiveDataCategoryBridge.personalInfo);
      }
      if (keyLower.contains('phone') || keyLower.contains('mobile')) {
        categories.add(SensitiveDataCategoryBridge.personalInfo);
      }
      if (keyLower.contains('location') || keyLower.contains('gps')) {
        categories.add(SensitiveDataCategoryBridge.location);
      }
      if (keyLower.contains('health') || keyLower.contains('medical')) {
        categories.add(SensitiveDataCategoryBridge.healthData);
      }
      if (keyLower.contains('financial') || keyLower.contains('payment')) {
        categories.add(SensitiveDataCategoryBridge.financialData);
      }
      if (keyLower.contains('biometric') || keyLower.contains('fingerprint')) {
        categories.add(SensitiveDataCategoryBridge.biometricData);
      }
      if (keyLower.contains('contact') || keyLower.contains('address')) {
        categories.add(SensitiveDataCategoryBridge.contactData);
      }
    });

    return categories;
  }

  void _walkParams(
    dynamic value,
    String prefix,
    void Function(String, dynamic) visitor,
  ) {
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString();
        visitor(key, entry.value);
        _walkParams(
          entry.value,
          prefix.isEmpty ? key : '$prefix.$key',
          visitor,
        );
      }
    } else if (value is List) {
      for (var i = 0; i < value.length; i++) {
        _walkParams(value[i], '$prefix[$i]', visitor);
      }
    }
  }
}

/// Bridge for Step 19's SensitiveDataCategory (18 values).
///
/// Step 19 defines these categories for data classification.
enum SensitiveDataCategoryBridge {
  personalInfo,
  authentication,
  financialData,
  healthData,
  biometricData,
  location,
  contactData,
  communicationData,
  browsingData,
  deviceData,
  usageData,
  preferences,
  behavioralData,
  childrensData,
  governmentId,
  ethnicity,
  religiousData,
  sexualOrientation,
  ;

  String get displayName {
    switch (this) {
      case SensitiveDataCategoryBridge.personalInfo: return 'Personal Info';
      case SensitiveDataCategoryBridge.authentication: return 'Authentication';
      case SensitiveDataCategoryBridge.financialData: return 'Financial Data';
      case SensitiveDataCategoryBridge.healthData: return 'Health Data';
      case SensitiveDataCategoryBridge.biometricData: return 'Biometric Data';
      case SensitiveDataCategoryBridge.location: return 'Location';
      case SensitiveDataCategoryBridge.contactData: return 'Contact Data';
      case SensitiveDataCategoryBridge.communicationData: return 'Communication Data';
      case SensitiveDataCategoryBridge.browsingData: return 'Browsing Data';
      case SensitiveDataCategoryBridge.deviceData: return 'Device Data';
      case SensitiveDataCategoryBridge.usageData: return 'Usage Data';
      case SensitiveDataCategoryBridge.preferences: return 'Preferences';
      case SensitiveDataCategoryBridge.behavioralData: return 'Behavioral Data';
      case SensitiveDataCategoryBridge.childrensData: return 'Children\'s Data';
      case SensitiveDataCategoryBridge.governmentId: return 'Government ID';
      case SensitiveDataCategoryBridge.ethnicity: return 'Ethnicity';
      case SensitiveDataCategoryBridge.religiousData: return 'Religious Data';
      case SensitiveDataCategoryBridge.sexualOrientation: return 'Sexual Orientation';
    }
  }
}
