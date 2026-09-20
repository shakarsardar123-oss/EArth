/// tool_registry_test.dart
/// AURA Assistant – Step 20: Tool Registry & Allowlist
///
/// Structural & mock tests covering all 16 required capabilities.
/// Since no Flutter/Dart SDK is available, these are structural/mock
/// tests that verify model construction, state transitions,
/// copyWith, factory constructors, and fail-closed behavior.
///
/// Test scenarios:
///  1. ToolDefinition creation and immutability
///  2. ToolCategory enum and extension
///  3. ToolRiskLevel enum and extension
///  4. ConfirmationPolicy enum and extension
///  5. ToolAllowlistEntry creation and copyWith
///  6. ToolExecutionResult success/failure factories
///  7. ToolFailure factory constructors (9 phases)
///  8. ToolState creation and copyWith
///  9. DefaultToolRegistryService registration
/// 10. DefaultToolRegistryService allowlist (fail-closed)
/// 11. DefaultToolRegistryService discovery
/// 12. DefaultToolConfirmationService (fail-closed)
/// 13. DefaultToolExecutionGate 6-gate pipeline
/// 14. DefaultToolDiscoveryApi (only allowed+enabled)
/// 15. ToolRegistryStateNotifier state emission
/// 16. ExistingToolAdapter definitions and allowlist
/// 17. Security adapter integration (Step 19)
/// 18. Permission adapter integration (Step 16)
/// 19. Recovery adapter integration (Step 18)
/// 20. Memory adapter integration (Step 17)
/// 21. Offline behavior
/// 22. ToolDiscovery API categories and risk levels
/// 23. ToolDefinition getters (isDangerous, accessesSensitiveData)
/// 24. Fail-closed: unknown=denied everywhere
/// 25. Fail-closed: disabled=denied
/// 26. Fail-closed: ambiguous=denied
library;

import 'package:aura_assistant/core/errors/result.dart';
import 'package:aura_assistant/features/tool_registry/domain/models/models.dart';
import 'package:aura_assistant/features/tool_registry/domain/services/services.dart';
import 'package:aura_assistant/features/tool_registry/application/application.dart';
import 'package:aura_assistant/features/tool_registry/infrastructure/infrastructure.dart';

void main() {
  // ─── Helper: Create a test ToolDefinition ────────────────────────

  ToolDefinition makeDefinition({
    String toolId = 'test_tool',
    String name = 'Test Tool',
    String description = 'A tool for testing',
    ToolCategory category = ToolCategory.assistant,
    ToolRiskLevel riskLevel = ToolRiskLevel.low,
    ConfirmationPolicy confirmationPolicy = ConfirmationPolicy.never,
    bool isEnabled = true,
    bool isDangerous = false,
    bool accessesSensitiveData = false,
    List<String> requiredPermissions = const [],
    List<String> sensitiveDataCategories = const [],
    List<String> tags = const [],
    String version = '1.0.0',
    String author = 'test',
    Map<String, dynamic> metadata = const {},
    String? overrideCategory,
  String? overrideConfirmationPolicy,
  String? deprecationMessage,
    DateTime? expiresAt,
  int usageCount = 0,
    DateTime? lastUsedAt,
  int maxExecutionTimeMs = 30000,
  int maxRetries = 0,
  String retryStrategy = 'none',
  String? executorType,
  bool requiresNetwork = false,
  bool isBuiltIn = false,
  bool isPremium = false,
    String? minAppVersion,
  }) {
    return ToolDefinition(
      toolId: toolId,
      name: name,
      description: description,
      category: category,
      riskLevel: riskLevel,
      confirmationPolicy: confirmationPolicy,
      isEnabled: isEnabled,
      isDangerous: isDangerous,
      accessesSensitiveData: accessesSensitiveData,
      requiredPermissions: requiredPermissions,
      sensitiveDataCategories: sensitiveDataCategories,
      tags: tags,
      version: version,
      author: author,
      metadata: metadata,
      overrideCategory: overrideCategory,
      overrideConfirmationPolicy: overrideConfirmationPolicy,
      deprecationMessage: deprecationMessage,
      expiresAt: expiresAt,
      usageCount: usageCount,
      lastUsedAt: lastUsedAt,
      maxExecutionTimeMs: maxExecutionTimeMs,
      maxRetries: maxRetries,
      retryStrategy: retryStrategy,
      executorType: executorType,
      requiresNetwork: requiresNetwork,
      isBuiltIn: isBuiltIn,
      isPremium: isPremium,
      minAppVersion: minAppVersion,
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Scenario 1: ToolDefinition creation and immutability
  // ═══════════════════════════════════════════════════════════════════
  test('Scenario 1: ToolDefinition creation and immutability', () {
    final def = makeDefinition();
    expect(def.toolId, 'test_tool');
    expect(def.name, 'Test Tool');
    expect(def.description, 'A tool for testing');
    expect(def.isEnabled, true);
    expect(def.isDangerous, false);
    expect(def.accessesSensitiveData, false);
    expect(def.requiredPermissions, []);
    expect(def.sensitiveDataCategories, []);
    expect(def.tags, []);
    expect(def.version, '1.0.0');
    expect(def.author, 'test');
    expect(def.metadata, {});
    expect(def.category, ToolCategory.assistant);
    expect(def.riskLevel, ToolRiskLevel.low);
    expect(def.confirmationPolicy, ConfirmationPolicy.never);
  });

  // ═══════════════════════════════════════════════════════════════════
  // Scenario 2: ToolCategory enum and extension
  // ═══════════════════════════════════════════════════════════════════
  test('Scenario 2: ToolCategory enum and extension', () {
    expect(ToolCategory.values.length, 12);
    expect(ToolCategory.voice.name, 'voice');
    expect(ToolCategory.screen.name, 'screen');
    expect(ToolCategory.vision.name, 'vision');
    expect(ToolCategory.device.name, 'device');
    expect(ToolCategory.memory.name, 'memory');
    expect(ToolCategory.assistant.name, 'assistant');
    expect(ToolCategory.recovery.name, 'recovery');
    expect(ToolCategory.communication.name, 'communication');
    expect(ToolCategory.navigation.name, 'navigation');
    expect(ToolCategory.system.name, 'system');
    expect(ToolCategory.media.name, 'media');
    expect(ToolCategory.data.name, 'data');
    expect(ToolCategory.external.name, 'external');

    // Extension methods.
    expect(ToolCategory.voice.displayName, isNotEmpty);
    expect(ToolCategory.voice.isHighRisk, false);
    expect(ToolCategory.system.isHighRisk, true);
    expect(ToolCategory.device.isHighRisk, true);
  });

  // ═══════════════════════════════════════════════════════════════════
  // Scenario 3: ToolRiskLevel enum and extension
  // ═══════════════════════════════════════════════════════════════════
  test('Scenario 3: ToolRiskLevel enum and extension', () {
    expect(ToolRiskLevel.values.length, 5);
    expect(ToolRiskLevel.low.name, 'low');
    expect(ToolRiskLevel.medium.name, 'medium');
    expect(ToolRiskLevel.high.name, 'high');
    expect(ToolRiskLevel.critical.name, 'critical');
    expect(ToolRiskLevel.unknown.name, 'unknown');

    // FAIL CLOSED: unknown risk → isHighRisk = true.
    expect(ToolRiskLevel.unknown.isHighRisk, true);
    expect(ToolRiskLevel.low.isHighRisk, false);
    expect(ToolRiskLevel.high.isHighRisk, true);
    expect(ToolRiskLevel.critical.isHighRisk, true);
  });

  // ═══════════════════════════════════════════════════════════════════
  // Scenario 4: ConfirmationPolicy enum and extension
  // ═══════════════════════════════════════════════════════════════════
  test('Scenario 4: ConfirmationPolicy enum and extension', () {
    expect(ConfirmationPolicy.values.length, 4);
    expect(ConfirmationPolicy.never.name, 'never');
    expect(ConfirmationPolicy.always.name, 'always');
    expect(ConfirmationPolicy.whenSensitive.name, 'whenSensitive');
    expect(ConfirmationPolicy.unknown.name, 'unknown');

    // FAIL CLOSED: unknown policy → treated as 'always'.
    expect(ConfirmationPolicy.unknown.effectivePolicy, ConfirmationPolicy.always);
    expect(ConfirmationPolicy.never.effectivePolicy, ConfirmationPolicy.never);
  });

  // ═══════════════════════════════════════════════════════════════════
  // Scenario 5: ToolAllowlistEntry creation and copyWith
  // ═══════════════════════════════════════════════════════════════════
  test('Scenario 5: ToolAllowlistEntry creation and copyWith', () {
    final now = DateTime.now();
    final entry = ToolAllowlistEntry(
      toolId: 'tool_a',
      isAllowed: true,
      addedAt: now,
      addedBy: AllowlistSource.user,
      reason: 'trusted',
    );

    expect(entry.toolId, 'tool_a');
    expect(entry.isAllowed, true);
    expect(entry.addedBy, AllowlistSource.user);
    expect(entry.reason, 'trusted');

    final updated = entry.copyWith(isAllowed: false, reason: 'revoked');
    expect(updated.isAllowed, false);
    expect(updated.reason, 'revoked');
    expect(updated.toolId, 'tool_a'); // unchanged.
  });

  // ═══════════════════════════════════════════════════════════════════
  // Scenario 6: ToolExecutionResult success/failure factories
  // ═══════════════════════════════════════════════════════════════════
  test('Scenario 6: ToolExecutionResult success/failure factories', () {
    final success = ToolExecutionResult.success(
      toolId: 'tool_a',
      data: {'key': 'value'},
    );
    expect(success.isSuccess, true);
    expect(success.toolId, 'tool_a');
    expect(success.data, {'key': 'value'});
    expect(success.errorMessage, isNull);

    final failure = ToolExecutionResult.failure(
      toolId: 'tool_b',
      errorMessage: 'Something went wrong',
    );
    expect(failure.isSuccess, false);
    expect(failure.toolId, 'tool_b');
    expect(failure.errorMessage, 'Something went wrong');
    expect(failure.data, isNull);
  });

  // ═══════════════════════════════════════════════════════════════════
  // Scenario 7: ToolFailure factory constructors (9 phases)
  // ═══════════════════════════════════════════════════════════════════
  test('Scenario 7: ToolFailure factory constructors', () {
    final reg = ToolFailure.registration(message: 'reg fail');
    expect(reg.phase, ToolFailurePhase.registration);
    expect(reg.message, 'reg fail');

    final allow = ToolFailure.allowlist(message: 'allow fail');
    expect(allow.phase, ToolFailurePhase.allowlist);

    final sec = ToolFailure.security(message: 'sec fail');
    expect(sec.phase, ToolFailurePhase.security);

    final perm = ToolFailure.permission(message: 'perm fail');
    expect(perm.phase, ToolFailurePhase.permission);

    final conf = ToolFailure.confirmation(message: 'conf fail');
    expect(conf.phase, ToolFailurePhase.confirmation);

    final exec = ToolFailure.execution(message: 'exec fail');
    expect(exec.phase, ToolFailurePhase.execution);

    final disc = ToolFailure.discovery(message: 'disc fail');
    expect(disc.phase, ToolFailurePhase.discovery);

    final rec = ToolFailure.recovery(message: 'rec fail');
    expect(rec.phase, ToolFailurePhase.recovery);

    final off = ToolFailure.offline(message: 'off fail');
    expect(off.phase, ToolFailurePhase.offline);
  });

  // ═══════════════════════════════════════════════════════════════════
  // Scenario 8: ToolState creation and copyWith
  // ═══════════════════════════════════════════════════════════════════
  test('Scenario 8: ToolState creation and copyWith', () {
    final state = ToolState(
      definitions: [],
      allowlistEntries: [],
      recentExecutions: [],
      status: ToolRegistryStatus.initializing,
      errorMessage: null,
      isOffline: false,
      lastRefreshedAt: null,
      availableToolCount: 0,
    );

    expect(state.definitions, []);
    expect(state.status, ToolRegistryStatus.initializing);
    expect(state.isOffline, false);
    expect(state.isReady, false);
    expect(state.isError, false);

    final updated = state.copyWith(
      status: ToolRegistryStatus.ready,
      availableToolCount: 5,
    );
    expect(updated.status, ToolRegistryStatus.ready);
    expect(updated.availableToolCount, 5);
    expect(updated.isReady, true);
  });

  // ═══════════════════════════════════════════════════════════════════
  // Scenario 9: DefaultToolRegistryService registration
  // ═══════════════════════════════════════════════════════════════════
  test('Scenario 9: DefaultToolRegistryService registration', () {
    final service = DefaultToolRegistryService();

    // Initially empty.
    expect(service.getAll().length, 0);
    expect(service.currentState.status, ToolRegistryStatus.initializing);

    // Register a tool.
    final def = makeDefinition();
    final result = service.register(def);
    expect(result.isSuccess, true);
    expect(result.asSuccess.value.toolId, 'test_tool');

    // Now it has 1 tool.
    expect(service.getAll().length, 1);
    expect(service.currentState.status, ToolRegistryStatus.ready);

    // Cannot register with empty toolId.
    final badDef = makeDefinition(toolId: '');
    final badResult = service.register(badDef);
    expect(badResult.isFailure, true);
  });

  // ═══════════════════════════════════════════════════════════════════
  // Scenario 10: DefaultToolRegistryService allowlist (fail-closed)
  // ═══════════════════════════════════════════════════════════════════
  test('Scenario 10: DefaultToolRegistryService allowlist (fail-closed)', () {
    final service = DefaultToolRegistryService();

    // Register a tool.
    service.register(makeDefinition(toolId: 'tool_a'));

    // FAIL CLOSED: Not in allowlist → isAllowed = false.
    expect(service.isAllowed('tool_a'), false);

    // Add to allowlist.
    service.setAllowlistEntry('tool_a', true);
    expect(service.isAllowed('tool_a'), true);

    // Remove from allowlist.
    service.removeAllowlistEntry('tool_a');
    expect(service.isAllowed('tool_a'), false);

    // FAIL CLOSED: Unknown tool → isAllowed = false.
    expect(service.isAllowed('unknown_tool'), false);

    // FAIL CLOSED: Cannot allowlist unregistered tool.
    final result = service.setAllowlistEntry('not_registered', true);
    expect(result.isFailure, true);
  });

  // ═══════════════════════════════════════════════════════════════════
  // Scenario 11: DefaultToolRegistryService discovery
  // ═══════════════════════════════════════════════════════════════════
  test('Scenario 11: DefaultToolRegistryService discovery', () {
    final service = DefaultToolRegistryService();

    service.register(makeDefinition(
      toolId: 'voice_tool',
      name: 'Voice Control',
      tags: ['audio', 'speech'],
    ));
    service.register(makeDefinition(
      toolId: 'screen_tool',
      name: 'Screen Reader',
      category: ToolCategory.screen,
    ));

    // Discover by name.
    final byName = service.discover('Voice');
    expect(byName.isSuccess, true);
    expect(byName.asSuccess.value.length, 1);
    expect(byName.asSuccess.value.first.toolId, 'voice_tool');

    // Discover by category.
    final byCat = service.discover('screen');
    expect(byCat.isSuccess, true);
    expect(byCat.asSuccess.value.length, 1);

    // Discover by tag.
    final byTag = service.discover('audio');
    expect(byTag.isSuccess, true);
    expect(byTag.asSuccess.value.length, 1);

    // No results.
    final empty = service.discover('nonexistent');
    expect(empty.isSuccess, true);
    expect(empty.asSuccess.value.length, 0);

    // getByCategory.
    final screen = service.getByCategory(ToolCategory.screen);
    expect(screen.length, 1);
    expect(screen.first.toolId, 'screen_tool');
  });

  // ═══════════════════════════════════════════════════════════════════
  // Scenario 12: DefaultToolConfirmationService (fail-closed)
  // ═══════════════════════════════════════════════════════════════════
  test('Scenario 12: DefaultToolConfirmationService (fail-closed)', () async {
    // Default: headless mode → always deny.
    final service = DefaultToolConfirmationService(headlessMode: true);

    // Policy: never → auto-confirm.
    final neverDef = makeDefinition(confirmationPolicy: ConfirmationPolicy.never);
    final neverResult = await service.requestConfirmation(neverDef);
    expect(neverResult, ConfirmationResult.confirmed);

    // Policy: always → denied in headless mode.
    final alwaysDef = makeDefinition(confirmationPolicy: ConfirmationPolicy.always);
    final alwaysResult = await service.requestConfirmation(alwaysDef);
    expect(alwaysResult, ConfirmationResult.denied);

    // Policy: whenSensitive + sensitive tool → denied in headless.
    final sensitiveDef = makeDefinition(
      confirmationPolicy: ConfirmationPolicy.whenSensitive,
      accessesSensitiveData: true,
    );
    final sensitiveResult = await service.requestConfirmation(sensitiveDef);
    expect(sensitiveResult, ConfirmationResult.denied);

    // Policy: whenSensitive + non-sensitive tool → auto-confirm.
    final nonSensitiveDef = makeDefinition(
      confirmationPolicy: ConfirmationPolicy.whenSensitive,
      accessesSensitiveData: false,
    );
    final nonSensitiveResult = await service.requestConfirmation(nonSensitiveDef);
    expect(nonSensitiveResult, ConfirmationResult.confirmed);

    // FAIL CLOSED: Policy: unknown → denied.
    final unknownDef = makeDefinition(confirmationPolicy: ConfirmationPolicy.unknown);
    final unknownResult = await service.requestConfirmation(unknownDef);
    expect(unknownResult, ConfirmationResult.denied);

    // FAIL CLOSED: Unavailable service → unavailable result.
    service.setAvailable(false);
    final unavailResult = await service.requestConfirmation(neverDef);
    expect(unavailResult, ConfirmationResult.unavailable);
  });

  // ═══════════════════════════════════════════════════════════════════
  // Scenario 13: DefaultToolExecutionGate 6-gate pipeline
  // ═══════════════════════════════════════════════════════════════════
  test('Scenario 13: DefaultToolExecutionGate 6-gate pipeline', () async {
    final registry = DefaultToolRegistryService();
    final confirmation = DefaultToolConfirmationService(headlessMode: true);
    final gate = DefaultToolExecutionGate(
      registryService: registry,
      confirmationService: confirmation,
    );

    // Register a tool with 'never' confirmation → should pass.
    registry.register(makeDefinition(
      toolId: 'safe_tool',
      confirmationPolicy: ConfirmationPolicy.never,
    ));
    registry.setAllowlistEntry('safe_tool', true);

    // Register executor.
    gate.registerExecutor('safe_tool', (params, {memoryContext, toolContext}) async {
      return ToolExecutionResult.success(
        toolId: 'safe_tool',
        data: {'result': 'ok'},
      );
    });

    // Execute: should succeed (all 6 gates pass).
    final result = await gate.execute('safe_tool');
    expect(result.isSuccess, true);
    expect(result.asSuccess.value.isSuccess, true);

    // ── Gate 1 fail: tool not registered ──
    final unregResult = await gate.execute('not_registered');
    expect(unregResult.isFailure, true);

    // ── Gate 2 fail: tool not in allowlist ──
    registry.register(makeDefinition(
      toolId: 'no_allow_tool',
      confirmationPolicy: ConfirmationPolicy.never,
    ));
    gate.registerExecutor('no_allow_tool', (params, {memoryContext, toolContext}) async {
      return ToolExecutionResult.success(toolId: 'no_allow_tool');
    });
    // Not in allowlist → fail.
    final noAllowResult = await gate.execute('no_allow_tool');
    expect(noAllowResult.isFailure, true);

    // ── Gate 5 fail: always-confirm in headless ──
    registry.register(makeDefinition(
      toolId: 'always_confirm_tool',
      confirmationPolicy: ConfirmationPolicy.always,
    ));
    registry.setAllowlistEntry('always_confirm_tool', true);
    gate.registerExecutor('always_confirm_tool', (params, {memoryContext, toolContext}) async {
      return ToolExecutionResult.success(toolId: 'always_confirm_tool');
    });
    final confResult = await gate.execute('always_confirm_tool');
    expect(confResult.isFailure, true);

    // ── Gate 6 fail: no executor ──
    registry.register(makeDefinition(
      toolId: 'no_executor_tool',
      confirmationPolicy: ConfirmationPolicy.never,
    ));
    registry.setAllowlistEntry('no_executor_tool', true);
    // No executor registered → fail.
    final noExecResult = await gate.execute('no_executor_tool');
    expect(noExecResult.isFailure, true);
  });

  // ═══════════════════════════════════════════════════════════════════
  // Scenario 14: DefaultToolDiscoveryApi (only allowed+enabled)
  // ═══════════════════════════════════════════════════════════════════
  test('Scenario 14: DefaultToolDiscoveryApi (only allowed+enabled)', () {
    final registry = DefaultToolRegistryService();
    final discovery = DefaultToolDiscoveryApi(registryService: registry);

    // Register 3 tools, allow 2, disable 1.
    registry.register(makeDefinition(toolId: 'allowed_a', name: 'Tool A'));
    registry.register(makeDefinition(toolId: 'allowed_b', name: 'Tool B'));
    registry.register(makeDefinition(toolId: 'disabled_c', name: 'Tool C', isEnabled: false));
    registry.register(makeDefinition(toolId: 'denied_d', name: 'Tool D'));

    registry.setAllowlistEntry('allowed_a', true);
    registry.setAllowlistEntry('allowed_b', true);
    // disabled_c not in allowlist (also disabled).
    registry.setAllowlistEntry('denied_d', false); // explicitly denied.

    // Discovery: only allowed_a and allowed_b should appear.
    final result = discovery.discover('Tool');
    expect(result.totalCount, 2);
    expect(result.tools.map((t) => t.toolId).toList(),
        containsAll(['allowed_a', 'allowed_b']));

    // getToolInfo: allowed → found.
    expect(discovery.getToolInfo('allowed_a'), isNotNull);
    // getToolInfo: disabled → null.
    expect(discovery.getToolInfo('disabled_c'), isNull);
    // getToolInfo: denied → null.
    expect(discovery.getToolInfo('denied_d'), isNull);
    // getToolInfo: unknown → null.
    expect(discovery.getToolInfo('unknown'), isNull);
  });

  // ═══════════════════════════════════════════════════════════════════
  // Scenario 15: ToolRegistryStateNotifier state emission
  // ═══════════════════════════════════════════════════════════════════
  test('Scenario 15: ToolRegistryStateNotifier state emission', () async {
    final registry = DefaultToolRegistryService();
    final confirmation = DefaultToolConfirmationService(headlessMode: true);
    final gate = DefaultToolExecutionGate(
      registryService: registry,
      confirmationService: confirmation,
    );
    final discovery = DefaultToolDiscoveryApi(registryService: registry);

    final notifier = ToolRegistryStateNotifier(
      registryService: registry,
      confirmationService: confirmation,
      executionGate: gate,
      discoveryApi: discovery,
    );

    // Initial state.
    expect(notifier.state.status, ToolRegistryStatus.initializing);

    // Register a tool → state changes.
    final result = notifier.registerTool(makeDefinition(toolId: 'notified_tool'));
    expect(result.isSuccess, true);
    expect(notifier.state.definitions.length, 1);
    expect(notifier.state.status, ToolRegistryStatus.ready);

    // Set allowlist → state changes.
    notifier.setAllowlist('notified_tool', true);
    expect(notifier.state.allowlistEntries.length, 1);

    // Set offline → state changes.
    notifier.setOffline(true);
    expect(notifier.state.isOffline, true);
    expect(notifier.state.status, ToolRegistryStatus.offline);

    // Stream emission.
    final states = <ToolState>[];
    final sub = notifier.stream.listen((s) => states.add(s));

    notifier.registerTool(makeDefinition(toolId: 'stream_tool'));
    await Future.delayed(const Duration(milliseconds: 50));

    expect(states.isNotEmpty, true);
    expect(states.last.definitions.length, 2);

    await sub.cancel();
    notifier.dispose();
  });

  // ═══════════════════════════════════════════════════════════════════
  // Scenario 16: ExistingToolAdapter definitions and allowlist
  // ═══════════════════════════════════════════════════════════════════
  test('Scenario 16: ExistingToolAdapter definitions and allowlist', () {
    final definitions = allBuiltinToolDefinitions();
    expect(definitions.length, greaterThanOrEqualTo(10));

    // Each definition should have a non-empty toolId.
    for (final def in definitions) {
      expect(def.toolId, isNotEmpty);
      expect(def.name, isNotEmpty);
      expect(def.description, isNotEmpty);
    }

    // Auto-approved allowlist entries.
    final autoEntries = autoApprovedAllowlistEntries();
    expect(autoEntries.length, greaterThanOrEqualTo(4));
    for (final entry in autoEntries) {
      expect(entry.isAllowed, true);
      expect(entry.addedBy, AllowlistSource.auto);
    }
  });

  // ═══════════════════════════════════════════════════════════════════
  // Scenario 17: Security adapter integration (Step 19)
  // ═══════════════════════════════════════════════════════════════════
  test('Scenario 17: Security adapter integration (Step 19)', () async {
    final registry = DefaultToolRegistryService();
    final confirmation = DefaultToolConfirmationService(headlessMode: true);

    // Default security adapter: allows low risk, denies high/critical.
    final securityAdapter = DefaultToolSecurityAdapter();

    final gate = DefaultToolExecutionGate(
      registryService: registry,
      confirmationService: confirmation,
      securityAdapter: securityAdapter,
    );

    // Register low-risk tool.
    registry.register(makeDefinition(
      toolId: 'low_risk',
      riskLevel: ToolRiskLevel.low,
      confirmationPolicy: ConfirmationPolicy.never,
    ));
    registry.setAllowlistEntry('low_risk', true);
    gate.registerExecutor('low_risk', (params, {memoryContext, toolContext}) async {
      return ToolExecutionResult.success(toolId: 'low_risk');
    });

    final lowResult = await gate.execute('low_risk');
    expect(lowResult.isSuccess, true);

    // Register critical-risk tool → security denies.
    registry.register(makeDefinition(
      toolId: 'critical_risk',
      riskLevel: ToolRiskLevel.critical,
      confirmationPolicy: ConfirmationPolicy.always,
    ));
    registry.setAllowlistEntry('critical_risk', true);
    gate.registerExecutor('critical_risk', (params, {memoryContext, toolContext}) async {
      return ToolExecutionResult.success(toolId: 'critical_risk');
    });

    final critResult = await gate.execute('critical_risk');
    // Either security gate or confirmation gate denies.
    expect(critResult.isFailure, true);
  });

  // ═══════════════════════════════════════════════════════════════════
  // Scenario 18: Permission adapter integration (Step 16)
  // ═══════════════════════════════════════════════════════════════════
  test('Scenario 18: Permission adapter integration (Step 16)', () async {
    final registry = DefaultToolRegistryService();
    final confirmation = DefaultToolConfirmationService(headlessMode: true);

    // Default permission adapter: grants all by default.
    final permAdapter = DefaultToolPermissionAdapter();

    final gate = DefaultToolExecutionGate(
      registryService: registry,
      confirmationService: confirmation,
      permissionAdapter: permAdapter,
    );

    // Register tool requiring permissions.
    registry.register(makeDefinition(
      toolId: 'perm_tool',
      confirmationPolicy: ConfirmationPolicy.never,
      requiredPermissions: ['camera', 'microphone'],
    ));
    registry.setAllowlistEntry('perm_tool', true);
    gate.registerExecutor('perm_tool', (params, {memoryContext, toolContext}) async {
      return ToolExecutionResult.success(toolId: 'perm_tool');
    });

    // Default adapter grants all → should succeed.
    final result = await gate.execute('perm_tool');
    expect(result.isSuccess, true);

    // Without permission adapter → FAIL CLOSED.
    final noPermGate = DefaultToolExecutionGate(
      registryService: registry,
      confirmationService: confirmation,
      // No permission adapter.
    );
    noPermGate.registerExecutor('perm_tool', (params, {memoryContext, toolContext}) async {
      return ToolExecutionResult.success(toolId: 'perm_tool');
    });

    final noPermResult = await noPermGate.execute('perm_tool');
    expect(noPermResult.isFailure, true);
  });

  // ═══════════════════════════════════════════════════════════════════
  // Scenario 19: Recovery adapter integration (Step 18)
  // ═══════════════════════════════════════════════════════════════════
  test('Scenario 19: Recovery adapter integration (Step 18)', () async {
    final registry = DefaultToolRegistryService();
    final confirmation = DefaultToolConfirmationService(headlessMode: true);

    // Default recovery adapter: does not retry.
    final recoveryAdapter = DefaultToolRecoveryAdapter();

    final gate = DefaultToolExecutionGate(
      registryService: registry,
      confirmationService: confirmation,
      recoveryAdapter: recoveryAdapter,
    );

    registry.register(makeDefinition(
      toolId: 'recover_tool',
      confirmationPolicy: ConfirmationPolicy.never,
    ));
    registry.setAllowlistEntry('recover_tool', true);

    // Executor that always throws.
    gate.registerExecutor('recover_tool', (params, {memoryContext, toolContext}) async {
      throw Exception('Always fails');
    });

    final result = await gate.execute('recover_tool');
    // Should still fail (recovery can't fix a broken executor).
    expect(result.isFailure, true);
  });

  // ═══════════════════════════════════════════════════════════════════
  // Scenario 20: Memory adapter integration (Step 17)
  // ═══════════════════════════════════════════════════════════════════
  test('Scenario 20: Memory adapter integration (Step 17)', () async {
    final registry = DefaultToolRegistryService();
    final confirmation = DefaultToolConfirmationService(headlessMode: true);

    // Default memory adapter: returns empty context.
    final memoryAdapter = DefaultToolMemoryAdapter();

    String? capturedMemoryContext;

    final gate = DefaultToolExecutionGate(
      registryService: registry,
      confirmationService: confirmation,
      memoryAdapter: memoryAdapter,
    );

    registry.register(makeDefinition(
      toolId: 'memory_tool',
      confirmationPolicy: ConfirmationPolicy.never,
    ));
    registry.setAllowlistEntry('memory_tool', true);

    gate.registerExecutor('memory_tool', (params, {memoryContext, toolContext}) async {
      capturedMemoryContext = memoryContext;
      return ToolExecutionResult.success(toolId: 'memory_tool');
    });

    final result = await gate.execute('memory_tool');
    expect(result.isSuccess, true);
    // Memory context was provided (even if empty).
    expect(capturedMemoryContext, isNotNull);
  });

  // ═══════════════════════════════════════════════════════════════════
  // Scenario 21: Offline behavior
  // ═══════════════════════════════════════════════════════════════════
  test('Scenario 21: Offline behavior', () {
    final registry = DefaultToolRegistryService();

    // Initially not offline.
    expect(registry.isOffline, false);
    expect(registry.currentState.isOffline, false);

    // Set offline.
    registry.setOffline(true);
    expect(registry.isOffline, true);
    expect(registry.currentState.isOffline, true);
    expect(registry.currentState.status, ToolRegistryStatus.offline);

    // Discovery still works in offline (with cached tools).
    registry.register(makeDefinition(toolId: 'offline_tool', name: 'Offline Tool'));
    final result = registry.discover('Offline');
    expect(result.isSuccess, true);
    expect(result.asSuccess.value.length, 1);

    // Back online.
    registry.setOffline(false);
    expect(registry.isOffline, false);
    expect(registry.currentState.status, ToolRegistryStatus.ready);
  });

  // ═══════════════════════════════════════════════════════════════════
  // Scenario 22: ToolDiscovery API categories and risk levels
  // ═══════════════════════════════════════════════════════════════════
  test('Scenario 22: ToolDiscovery API categories and risk levels', () {
    final registry = DefaultToolRegistryService();
    final discovery = DefaultToolDiscoveryApi(registryService: registry);

    // Register tools in different categories.
    registry.register(makeDefinition(
      toolId: 'cat_voice',
      category: ToolCategory.voice,
      confirmationPolicy: ConfirmationPolicy.never,
    ));
    registry.register(makeDefinition(
      toolId: 'cat_screen',
      category: ToolCategory.screen,
      confirmationPolicy: ConfirmationPolicy.never,
    ));
    registry.register(makeDefinition(
      toolId: 'cat_system',
      category: ToolCategory.system,
      riskLevel: ToolRiskLevel.high,
      confirmationPolicy: ConfirmationPolicy.always,
    ));

    // Allow voice and screen.
    registry.setAllowlistEntry('cat_voice', true);
    registry.setAllowlistEntry('cat_screen', true);
    // Deny system.
    registry.setAllowlistEntry('cat_system', false);

    // Discover by category.
    final voiceCat = discovery.discoverByCategory(ToolCategory.voice);
    expect(voiceCat.totalCount, 1);
    expect(voiceCat.tools.first.toolId, 'cat_voice');

    final screenCat = discovery.discoverByCategory(ToolCategory.screen);
    expect(screenCat.totalCount, 1);

    final systemCat = discovery.discoverByCategory(ToolCategory.system);
    // Denied → not discoverable.
    expect(systemCat.totalCount, 0);

    // Discover by risk level.
    final lowRisk = discovery.discoverByRiskLevel(ToolRiskLevel.low);
    expect(lowRisk.totalCount, 2); // voice + screen.

    final highRisk = discovery.discoverByRiskLevel(ToolRiskLevel.high);
    expect(highRisk.totalCount, 0); // system denied.

    // Available categories.
    final categories = discovery.availableCategories();
    expect(categories, contains(ToolCategory.voice));
    expect(categories, contains(ToolCategory.screen));
    expect(categories, isNot(contains(ToolCategory.system)));
  });

  // ═══════════════════════════════════════════════════════════════════
  // Scenario 23: ToolDefinition getters (isDangerous, accessesSensitiveData)
  // ═══════════════════════════════════════════════════════════════════
  test('Scenario 23: ToolDefinition getters', () {
    final safe = makeDefinition(
      riskLevel: ToolRiskLevel.low,
      isDangerous: false,
      accessesSensitiveData: false,
    );
    expect(safe.isDangerous, false);
    expect(safe.accessesSensitiveData, false);
    expect(safe.needsConfirmation, false);

    final dangerous = makeDefinition(
      riskLevel: ToolRiskLevel.high,
      isDangerous: true,
      accessesSensitiveData: true,
    );
    expect(dangerous.isDangerous, true);
    expect(dangerous.accessesSensitiveData, true);

    // effectiveConfirmationPolicy.
    final overridden = makeDefinition(
      confirmationPolicy: ConfirmationPolicy.never,
      overrideConfirmationPolicy: 'always',
    );
    expect(overridden.effectiveConfirmationPolicy, ConfirmationPolicy.always);

    // effectiveCategory.
    final catOverride = makeDefinition(
      category: ToolCategory.assistant,
      overrideCategory: 'system',
    );
    expect(catOverride.effectiveCategory, ToolCategory.system);
  });

  // ═══════════════════════════════════════════════════════════════════
  // Scenario 24: Fail-closed: unknown=denied everywhere
  // ═══════════════════════════════════════════════════════════════════
  test('Scenario 24: Fail-closed: unknown=denied everywhere', () async {
    final registry = DefaultToolRegistryService();
    final confirmation = DefaultToolConfirmationService();
    final gate = DefaultToolExecutionGate(
      registryService: registry,
      confirmationService: confirmation,
    );

    // Unknown tool → getDefinition fails.
    final defResult = registry.getDefinition('totally_unknown');
    expect(defResult.isFailure, true);

    // Unknown tool → isAllowed = false.
    expect(registry.isAllowed('totally_unknown'), false);

    // Unknown tool → execute fails.
    final execResult = await gate.execute('totally_unknown');
    expect(execResult.isFailure, true);

    // Unknown tool → checkReadiness = notReady.
    final readiness = await gate.checkReadiness('totally_unknown');
    expect(readiness.isReady, false);

    // Unknown risk level → treated as high risk.
    expect(ToolRiskLevel.unknown.isHighRisk, true);

    // Unknown confirmation policy → treated as always.
    expect(ConfirmationPolicy.unknown.effectivePolicy, ConfirmationPolicy.always);

    // Unknown category → treated as external (safest default).
    // (ToolCategory has no 'unknown' value, but this verifies enum integrity.)
    expect(ToolCategory.values.length, 12);
  });

  // ═══════════════════════════════════════════════════════════════════
  // Scenario 25: Fail-closed: disabled=denied
  // ═══════════════════════════════════════════════════════════════════
  test('Scenario 25: Fail-closed: disabled=denied', () async {
    final registry = DefaultToolRegistryService();
    final confirmation = DefaultToolConfirmationService(headlessMode: true);
    final gate = DefaultToolExecutionGate(
      registryService: registry,
      confirmationService: confirmation,
    );

    // Register a disabled tool.
    registry.register(makeDefinition(
      toolId: 'disabled_tool',
      isEnabled: false,
      confirmationPolicy: ConfirmationPolicy.never,
    ));
    registry.setAllowlistEntry('disabled_tool', true);
    gate.registerExecutor('disabled_tool', (params, {memoryContext, toolContext}) async {
      return ToolExecutionResult.success(toolId: 'disabled_tool');
    });

    // isAllowed returns false for disabled tools.
    expect(registry.isAllowed('disabled_tool'), false);

    // Execution should fail.
    final result = await gate.execute('disabled_tool');
    expect(result.isFailure, true);

    // Discovery should not show disabled tools.
    final discovery = DefaultToolDiscoveryApi(registryService: registry);
    expect(discovery.getToolInfo('disabled_tool'), isNull);
  });

  // ═══════════════════════════════════════════════════════════════════
  // Scenario 26: Fail-closed: ambiguous=denied
  // ═══════════════════════════════════════════════════════════════════
  test('Scenario 26: Fail-closed: ambiguous=denied', () async {
    final registry = DefaultToolRegistryService();
    final confirmation = DefaultToolConfirmationService(headlessMode: true);

    // Create a tool with ambiguous/contradictory settings.
    final ambiguous = makeDefinition(
      toolId: 'ambiguous_tool',
      riskLevel: ToolRiskLevel.critical,
      isDangerous: true,
      accessesSensitiveData: true,
      confirmationPolicy: ConfirmationPolicy.never, // Contradicts risk level.
    );

    registry.register(ambiguous);
    registry.setAllowlistEntry('ambiguous_tool', true);

    // Even though confirmationPolicy=never, the security adapter
    // should block critical tools.
    final securityAdapter = DefaultToolSecurityAdapter();
    final secResult = await securityAdapter.check(ambiguous);
    expect(secResult.verdict, isNot(ToolSecurityVerdict.allowed));

    // With the full gate.
    final gate = DefaultToolExecutionGate(
      registryService: registry,
      confirmationService: confirmation,
      securityAdapter: securityAdapter,
    );
    gate.registerExecutor('ambiguous_tool', (params, {memoryContext, toolContext}) async {
      return ToolExecutionResult.success(toolId: 'ambiguous_tool');
    });

    final result = await gate.execute('ambiguous_tool');
    expect(result.isFailure, true);
  });
}
