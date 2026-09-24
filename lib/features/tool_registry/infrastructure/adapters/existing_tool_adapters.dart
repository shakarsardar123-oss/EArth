/// existing_tool_adapters.dart
/// AURA Assistant – Step 20: Tool Registry & Allowlist
///
/// Adapters for existing tools from Steps 15-18, providing
/// [ToolDefinition] registrations for each known tool.
///
/// These adapters allow the Tool Registry to discover, categorize,
/// and manage tools that already exist in the AURA Assistant system.
library;

import 'package:texo/features/tool_registry/domain/models/models.dart';

/// Base class for existing tool adapters.
///
/// Provides the [ToolDefinition] and default allowlist entry
/// for a specific existing tool.
abstract class ExistingToolAdapter {
  /// The tool definition for this existing tool.
  ToolDefinition get definition;

  /// Whether this tool should be auto-approved on the allowlist.
  ///
  /// FAIL CLOSED: defaults to false. Only override to true
  /// for tools that are inherently safe (e.g., read-only, no PII).
  bool get autoApprove => false;

  /// Default allowlist source if auto-approved.
  AllowlistSource get defaultAllowlistSource =>
      autoApprove ? AllowlistSource.autoApproved : AllowlistSource.unknown;

  /// Default reason for the allowlist entry.
  String get defaultAllowlistReason =>
      autoApprove ? 'Auto-approved: inherently safe tool' : '';

  /// Create the default allowlist entry for this tool.
  ToolAllowlistEntry defaultAllowlistEntry() {
    return ToolAllowlistEntry(
      toolId: definition.toolId,
      isAllowed: autoApprove,
      addedAt: DateTime.now(),
      addedBy: defaultAllowlistSource,
      reason: defaultAllowlistReason,
    );
  }
}

// ─── Voice Tool (Step 15) ─────────────────────────────────────────────

/// Adapter for the Voice/TTS tool from Step 15.
///
/// Voice tools access the microphone and produce audio output.
/// They are classified as [ToolCategory.voice] with medium risk.
class VoiceToolAdapter extends ExistingToolAdapter {
  final String toolId;
  final String name;
  final String description;

  VoiceToolAdapter({
    this.toolId = 'voice_tts',
    this.name = 'Voice (TTS)',
    this.description = 'Text-to-speech and voice interaction tool',
  });

  @override
  ToolDefinition get definition => ToolDefinition(
        toolId: toolId,
        name: name,
        description: description,
        category: ToolCategory.voice,
        riskLevel: ToolRiskLevel.medium,
        confirmationPolicy: ConfirmationPolicy.whenSensitive,
        accessedCategories: const ['audio'],
        requiresNetwork: false,
        modifiesState: true,
        canExfiltrateData: false,
        isEnabled: true,
        version: '1.0.0',
        iconKey: 'mic',
        tags: const ['voice', 'tts', 'audio', 'output'],
        requiredPermissions: const ['microphone'],
      );

  @override
  bool get autoApprove => false; // Requires microphone permission
}

// ─── Screen Tool (Step 15) ───────────────────────────────────────────

/// Adapter for the Screen/UI tool from Step 15.
///
/// Screen tools interact with the device display.
class ScreenToolAdapter extends ExistingToolAdapter {
  final String toolId;
  final String name;
  final String description;

  ScreenToolAdapter({
    this.toolId = 'screen_control',
    this.name = 'Screen Control',
    this.description = 'Screen and UI interaction tool',
  });

  @override
  ToolDefinition get definition => ToolDefinition(
        toolId: toolId,
        name: name,
        description: description,
        category: ToolCategory.screen,
        riskLevel: ToolRiskLevel.medium,
        confirmationPolicy: ConfirmationPolicy.whenSensitive,
        accessedCategories: const ['screen'],
        requiresNetwork: false,
        modifiesState: true,
        canExfiltrateData: false,
        isEnabled: true,
        version: '1.0.0',
        iconKey: 'screen',
        tags: const ['screen', 'ui', 'display'],
        requiredPermissions: const [],
      );

  @override
  bool get autoApprove => false; // Modifies state
}

// ─── Vision Tool (Step 15) ───────────────────────────────────────────

/// Adapter for the Vision/camera tool from Step 15.
///
/// Vision tools access the camera and process visual data.
/// High risk due to PII exposure.
class VisionToolAdapter extends ExistingToolAdapter {
  final String toolId;
  final String name;
  final String description;

  VisionToolAdapter({
    this.toolId = 'vision_camera',
    this.name = 'Vision (Camera)',
    this.description = 'Camera and visual recognition tool',
  });

  @override
  ToolDefinition get definition => ToolDefinition(
        toolId: toolId,
        name: name,
        description: description,
        category: ToolCategory.vision,
        riskLevel: ToolRiskLevel.high,
        confirmationPolicy: ConfirmationPolicy.always,
        accessedCategories: const ['camera', 'images'],
        requiresNetwork: true,
        modifiesState: false,
        canExfiltrateData: true,
        isEnabled: true,
        version: '1.0.0',
        iconKey: 'camera',
        tags: const ['vision', 'camera', 'image', 'recognition'],
        requiredPermissions: const ['camera'],
      );

  @override
  bool get autoApprove => false; // High risk, requires camera
}

// ─── Device Tool (Step 15) ───────────────────────────────────────────

/// Adapter for the Device/sensors tool from Step 15.
///
/// Device tools access hardware sensors and features.
class DeviceToolAdapter extends ExistingToolAdapter {
  final String toolId;
  final String name;
  final String description;

  DeviceToolAdapter({
    this.toolId = 'device_sensors',
    this.name = 'Device Sensors',
    this.description = 'Device sensor and hardware access tool',
  });

  @override
  ToolDefinition get definition => ToolDefinition(
        toolId: toolId,
        name: name,
        description: description,
        category: ToolCategory.device,
        riskLevel: ToolRiskLevel.medium,
        confirmationPolicy: ConfirmationPolicy.whenSensitive,
        accessedCategories: const ['sensors', 'location'],
        requiresNetwork: false,
        modifiesState: false,
        canExfiltrateData: true,
        isEnabled: true,
        version: '1.0.0',
        iconKey: 'device',
        tags: const ['device', 'sensors', 'hardware'],
        requiredPermissions: const ['sensors', 'location'],
      );

  @override
  bool get autoApprove => false; // Accesses location and sensors
}

// ─── Memory Tool (Step 17) ───────────────────────────────────────────

/// Adapter for the Memory tool from Step 17.
///
/// Memory tools store and recall information.
/// Medium risk – can store sensitive data.
class MemoryToolAdapter extends ExistingToolAdapter {
  final String toolId;
  final String name;
  final String description;

  MemoryToolAdapter({
    this.toolId = 'memory_manager',
    this.name = 'Memory Manager',
    this.description = 'Store, recall, search, and manage memories',
  });

  @override
  ToolDefinition get definition => ToolDefinition(
        toolId: toolId,
        name: name,
        description: description,
        category: ToolCategory.memory,
        riskLevel: ToolRiskLevel.medium,
        confirmationPolicy: ConfirmationPolicy.whenSensitive,
        accessedCategories: const ['memory'],
        requiresNetwork: false,
        modifiesState: true,
        canExfiltrateData: true,
        isEnabled: true,
        version: '1.0.0',
        iconKey: 'memory',
        tags: const ['memory', 'storage', 'recall', 'search'],
        requiredPermissions: const [],
      );

  @override
  bool get autoApprove => false; // Can store sensitive data
}

// ─── Assistant Tool (Step 15) ────────────────────────────────────────

/// Adapter for the core Assistant tool from Step 15.
///
/// The assistant itself is a tool – manages conversation and actions.
class AssistantToolAdapter extends ExistingToolAdapter {
  final String toolId;
  final String name;
  final String description;

  AssistantToolAdapter({
    this.toolId = 'aura_assistant',
    this.name = 'AURA',
    this.description = 'Core AI assistant – conversation and action management',
  });

  @override
  ToolDefinition get definition => ToolDefinition(
        toolId: toolId,
        name: name,
        description: description,
        category: ToolCategory.assistant,
        riskLevel: ToolRiskLevel.low,
        confirmationPolicy: ConfirmationPolicy.whenSensitive,
        accessedCategories: const ['conversation'],
        requiresNetwork: true,
        modifiesState: true,
        canExfiltrateData: false,
        isEnabled: true,
        version: '1.0.0',
        iconKey: 'assistant',
        tags: const ['assistant', 'ai', 'conversation', 'core'],
        requiredPermissions: const [],
      );

  @override
  bool get autoApprove => true; // Core assistant – inherently required
}

// ─── Recovery Tool (Step 18) ─────────────────────────────────────────

/// Adapter for the Recovery tool from Step 18.
///
/// Recovery tools attempt to fix failures and retry actions.
class RecoveryToolAdapter extends ExistingToolAdapter {
  final String toolId;
  final String name;
  final String description;

  RecoveryToolAdapter({
    this.toolId = 'recovery_coordinator',
    this.name = 'Recovery Coordinator',
    this.description = 'Recover from failures and retry actions',
  });

  @override
  ToolDefinition get definition => ToolDefinition(
        toolId: toolId,
        name: name,
        description: description,
        category: ToolCategory.recovery,
        riskLevel: ToolRiskLevel.low,
        confirmationPolicy: ConfirmationPolicy.never,
        accessedCategories: const [],
        requiresNetwork: false,
        modifiesState: true,
        canExfiltrateData: false,
        isEnabled: true,
        version: '1.0.0',
        iconKey: 'recovery',
        tags: const ['recovery', 'retry', 'resilience'],
        requiredPermissions: const [],
      );

  @override
  bool get autoApprove => true; // Recovery is inherently safe
}

// ─── Communication Tool ──────────────────────────────────────────────

/// Adapter for a Communication tool.
///
/// Communication tools send messages, make calls, etc.
class CommunicationToolAdapter extends ExistingToolAdapter {
  final String toolId;
  final String name;
  final String description;

  CommunicationToolAdapter({
    this.toolId = 'communication',
    this.name = 'Communication',
    this.description = 'Send messages, make calls, and communicate',
  });

  @override
  ToolDefinition get definition => ToolDefinition(
        toolId: toolId,
        name: name,
        description: description,
        category: ToolCategory.communication,
        riskLevel: ToolRiskLevel.high,
        confirmationPolicy: ConfirmationPolicy.always,
        accessedCategories: const ['contacts', 'messages'],
        requiresNetwork: true,
        modifiesState: true,
        canExfiltrateData: true,
        isEnabled: true,
        version: '1.0.0',
        iconKey: 'communication',
        tags: const ['communication', 'messages', 'calls'],
        requiredPermissions: const ['contacts', 'phone'],
      );

  @override
  bool get autoApprove => false; // High risk
}

// ─── Navigation Tool ─────────────────────────────────────────────────

/// Adapter for a Navigation tool.
///
/// Navigation tools handle routing and navigation.
class NavigationToolAdapter extends ExistingToolAdapter {
  final String toolId;
  final String name;
  final String description;

  NavigationToolAdapter({
    this.toolId = 'navigation',
    this.name = 'Navigation',
    this.description = 'Navigation and routing tool',
  });

  @override
  ToolDefinition get definition => ToolDefinition(
        toolId: toolId,
        name: name,
        description: description,
        category: ToolCategory.navigation,
        riskLevel: ToolRiskLevel.low,
        confirmationPolicy: ConfirmationPolicy.never,
        accessedCategories: const [],
        requiresNetwork: false,
        modifiesState: true,
        canExfiltrateData: false,
        isEnabled: true,
        version: '1.0.0',
        iconKey: 'navigation',
        tags: const ['navigation', 'routing', 'directions'],
        requiredPermissions: const [],
      );

  @override
  bool get autoApprove => true; // Navigation is inherently safe
}

// ─── System Tool ─────────────────────────────────────────────────────

/// Adapter for a System tool.
///
/// System tools manage app-level settings and configuration.
class SystemToolAdapter extends ExistingToolAdapter {
  final String toolId;
  final String name;
  final String description;

  SystemToolAdapter({
    this.toolId = 'system_config',
    this.name = 'System Configuration',
    this.description = 'Manage app settings and system configuration',
  });

  @override
  ToolDefinition get definition => ToolDefinition(
        toolId: toolId,
        name: name,
        description: description,
        category: ToolCategory.system,
        riskLevel: ToolRiskLevel.high,
        confirmationPolicy: ConfirmationPolicy.always,
        accessedCategories: const ['system'],
        requiresNetwork: false,
        modifiesState: true,
        canExfiltrateData: false,
        isEnabled: true,
        version: '1.0.0',
        iconKey: 'settings',
        tags: const ['system', 'config', 'settings'],
        requiredPermissions: const [],
      );

  @override
  bool get autoApprove => false; // System config is high risk
}

// ─── Media Tool ──────────────────────────────────────────────────────

/// Adapter for a Media tool.
///
/// Media tools handle media playback, recording, etc.
class MediaToolAdapter extends ExistingToolAdapter {
  final String toolId;
  final String name;
  final String description;

  MediaToolAdapter({
    this.toolId = 'media_playback',
    this.name = 'Media Playback',
    this.description = 'Play and control media content',
  });

  @override
  ToolDefinition get definition => ToolDefinition(
        toolId: toolId,
        name: name,
        description: description,
        category: ToolCategory.media,
        riskLevel: ToolRiskLevel.low,
        confirmationPolicy: ConfirmationPolicy.never,
        accessedCategories: const ['media'],
        requiresNetwork: true,
        modifiesState: false,
        canExfiltrateData: false,
        isEnabled: true,
        version: '1.0.0',
        iconKey: 'media',
        tags: const ['media', 'playback', 'audio', 'video'],
        requiredPermissions: const [],
      );

  @override
  bool get autoApprove => true; // Playback is inherently safe
}

// ─── Registry Helper ─────────────────────────────────────────────────

/// Helper to register all known existing tools.
///
/// Returns a list of all built-in tool adapters for bulk registration.
List<ExistingToolAdapter> allExistingToolAdapters() => [
      VoiceToolAdapter(),
      ScreenToolAdapter(),
      VisionToolAdapter(),
      DeviceToolAdapter(),
      MemoryToolAdapter(),
      AssistantToolAdapter(),
      RecoveryToolAdapter(),
      CommunicationToolAdapter(),
      NavigationToolAdapter(),
      SystemToolAdapter(),
      MediaToolAdapter(),
    ];

/// Get all built-in tool definitions.
List<ToolDefinition> allBuiltinToolDefinitions() =>
    allExistingToolAdapters().map((a) => a.definition).toList();

/// Get default allowlist entries for all auto-approved tools.
List<ToolAllowlistEntry> autoApprovedAllowlistEntries() =>
    allExistingToolAdapters()
        .where((a) => a.autoApprove)
        .map((a) => a.defaultAllowlistEntry())
        .toList();
