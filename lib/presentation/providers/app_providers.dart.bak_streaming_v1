/// app_providers.dart
/// AURA Assistant – P1 Fix: Gemini-First Provider Routing
///
/// UPDATED: Gemini is now the primary AI provider.
/// - Added [geminiProviderProvider] for native Gemini REST API.
/// - [selectedAIProviderProvider] now routes Gemini type to GeminiProvider.
/// - OpenAI Provider is kept for openaiCompatible and customOpenAI types.
/// - Default AgentConfig modelId changed to gemini-3.6-flash.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/localization/locale_provider.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/agent/agent_engine.dart';
import '../../core/agent/agent_context.dart';
import '../../core/ai/agent_engine_adapter.dart';
import '../../core/tools/tool_registry.dart';
import '../../core/memory/memory_database.dart';
import '../../core/memory/memory_repository_impl.dart';
import '../../services/memory/memory_service.dart';
import '../../data/datasources/local_storage_data_source.dart';
import '../../data/repositories/agent_config_repository_impl.dart';
import '../../data/repositories/app_config_repository_impl.dart';
import '../../domain/entities/agent_config.dart';
import '../../domain/repositories/agent_config_repository.dart';
import '../../domain/repositories/app_config_repository.dart';
import '../../core/errors/result.dart';
import '../../services/ai/ai_provider.dart';
import '../../core/ai/connection_type.dart';
import '../../core/ai/gemini_provider.dart' show GeminiProvider;
import 'dart:io' show Platform;
import '../../core/device/device_service_impl.dart';
import '../../core/device/device_channel.dart';
import '../../core/device/android_device_channel.dart';
import '../../core/device/stub_device_channel.dart';
// ── Phase 6: System Control channel (additive, separate from DeviceChannel) ──
import '../../core/device/system_control_channel.dart';
import '../../core/device/android_system_control_channel.dart';
import '../../core/device/stub_system_control_channel.dart';
import '../../core/tools/device/device_tools.dart';
import '../../core/tools/alarms/create_alarm_tool.dart';
import '../../core/tools/alarms/list_alarms_tool.dart';
import '../../core/tools/alarms/update_alarm_tool.dart';
import '../../core/tools/alarms/delete_alarm_tool.dart';
import '../../core/tools/alarms/set_alarm_tool.dart';
import '../../core/tools/vision/vision_tools.dart';
// ── Security providers ───────────────────────────────────────────
// core/security: ToolSecurityGate, confirmation guard (used by AgentEngine)
import '../../core/security/security_providers.dart';
// features/security: Secret scanner, redactor, logger, audit (R4 wiring)
import '../../features/security/presentation/security_providers.dart'
    show
        securitySecretScannerProvider,
        securitySensitiveDataRedactorProvider,
        securitySecureLoggerProvider,
        securityAuditServiceProvider;
import 'security_confirmation_provider.dart';
import 'alarm_tool_gateway_impl.dart' show alarmToolGatewayProvider;
import '../../services/camera/vision_camera_service.dart'
    show visionCameraServiceProvider;
import '../../services/vision/vision_service_factory.dart' show visionServiceProvider;
import '../../core/screen_capture/screen_capture_provider.dart'
    show
        screenCaptureServiceProvider,
        screenCaptureStateProvider,
        screenCaptureFrameStreamProvider,
        screenCaptureSupportedProvider;
import '../../core/floating_aura/floating_aura_provider.dart'
    show
        floatingAuraServiceProvider,
        floatingAuraSupportedProvider,
        floatingAuraStateProvider;
import '../../core/screen_understanding/screen_understanding_provider.dart'
    show
        screenUnderstandingServiceProvider,
        screenUnderstandingStateProvider;
import '../../core/ai/ai_connection_storage.dart';
import '../../core/ai/auto_model_provider.dart' show AutoModelProvider;
import '../../core/ai/model_discovery.dart' show ModelSelector;
import '../../core/ai/provider_registry.dart';
import '../../core/screen_search/search_provider.dart'
    show screenSearchServiceProvider, screenSearchStateProvider;
// ── Semantic Memory (Phase 1 wiring) ─────────────────────────────────
import '../../features/semantic_memory/application/memory_providers.dart'
    as semantic_memory;
import '../../features/semantic_memory/application/memory_manager.dart'
    show MemoryManager;
import '../../features/semantic_memory/application/agent_memory_integration.dart'
    show AgentMemoryIntegration;
import '../../features/semantic_memory/adapters/agent_context_adapter.dart'
    show AgentContextAdapter;
// ── Orchestration (Step 23) wiring ───────────────────────────────────
// Repository interfaces (typing) + infrastructure adapters (impls) +
// the OrchestrationProviders factory. Adapters are imported behind the
// `orch` prefix so their concrete class names never leak into the rest
// of this file — providers are always exposed as repository interfaces.
import '../../core/agent/agent_executor.dart'
    show AgentExecutor, CancellationToken;
import '../../core/agent/agent_recovery.dart' as core_recovery;
import '../../core/permissions/permission_provider.dart'
    show permissionServiceProvider;
import '../../features/semantic_memory/application/providers/memory_context_provider.dart'
    show memoryContextProvider;
import '../../features/orchestration/domain/repositories/repositories.dart';
import '../../features/orchestration/infrastructure/adapters/adapters.dart'
    as orch;
import '../../features/orchestration/application/localization_service.dart'
    show AppLocalizationService;
import '../../features/orchestration/application/providers/orchestration_providers.dart'
    show OrchestrationProviders;
import '../../features/orchestration/application/orchestrator/agent_orchestrator.dart'
    show AgentOrchestrator;
import '../../features/orchestration/application/usecases/orchestration_use_case.dart'
    show OrchestrationUseCase;
import '../../features/trigger_integration/application/controller/trigger_controller.dart';
import '../../features/device_integration/application/providers.dart' as device_integration;
import '../../features/trigger_integration/application/providers/trigger_providers.dart';
import '../../features/trigger_integration/domain/repositories/trigger_authorization_repository.dart'
    as trigger_auth;
import '../../features/trigger_integration/infrastructure/adapters/security_bridge_adapter.dart';
import '../../features/trigger_integration/infrastructure/adapters/trigger_orchestration_adapter.dart';
import '../../features/trigger_integration/infrastructure/platform/trigger_platform_service.dart';
import '../../features/trigger_integration/infrastructure/platform/trigger_runtime_service.dart';


// ─── Phase 1+2 Providers ────────────────────────────────────────────

/// Provider for [SharedPreferences]. Must be overridden in main.dart.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in main.dart',
  );
});

/// Provider for [LocalStorageDataSource].
final localStorageDataSourceProvider = Provider<LocalStorageDataSource>((ref) {
  return LocalStorageDataSource(ref.watch(sharedPreferencesProvider));
});

/// Provider for [AppConfigRepository].
final appConfigRepositoryProvider = Provider<AppConfigRepository>((ref) {
  return AppConfigRepositoryImpl(ref.watch(localStorageDataSourceProvider));
});

/// Provider for [AgentConfigRepository].
final agentConfigRepositoryProvider = Provider<AgentConfigRepository>((ref) {
  return AgentConfigRepositoryImpl();
});

/// Overridden theme provider wired to [SharedPreferences].
final overriddenThemeProvider = StateNotifierProvider<ThemeNotifier, AuraThemeMode>((ref) {
  return ThemeNotifier(ref.watch(sharedPreferencesProvider));
});

/// Overridden locale provider wired to [SharedPreferences].
final overriddenLocaleProvider = StateNotifierProvider<LocaleNotifier, AuraLocale>((ref) {
  return LocaleNotifier(ref.watch(sharedPreferencesProvider));
});

/// Resolves the [ThemeData] from the current [AuraThemeMode].
final themeDataProvider = Provider<ThemeData>((ref) {
  final mode = ref.watch(overriddenThemeProvider);
  switch (mode) {
    case AuraThemeMode.dark:
      return AppTheme.dark();
    case AuraThemeMode.light:
      return AppTheme.light();
    case AuraThemeMode.natural:
      return AppTheme.natural();
    case AuraThemeMode.system:
      return AppTheme.dark();
  }
});

// ─── Phase 3 Providers ──────────────────────────────────────────────

/// Provider for [FlutterSecureStorage]. Must be overridden in main.dart.
final flutterSecureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  throw UnimplementedError(
    'flutterSecureStorageProvider must be overridden in main.dart',
  );
});

/// Provider for [AIConnectionStorage]. Depends on
/// [flutterSecureStorageProvider] + [sharedPreferencesProvider].
/// Must be overridden in main.dart.
final aiConnectionStorageProvider = Provider<AIConnectionStorage>((ref) {
  throw UnimplementedError(
    'aiConnectionStorageProvider must be overridden in main.dart',
  );
});

/// Provider for [AIProvider] (OpenAI-compatible).
/// Must be overridden in main.dart.
/// Used ONLY for openaiCompatible and customOpenAI connection types.
final openaiProviderProvider = Provider<AIProvider>((ref) {
  throw UnimplementedError(
    'openaiProviderProvider must be overridden in main.dart',
  );
});

/// Provider for [GeminiProvider] (native Gemini REST API).
/// Must be overridden in main.dart.
/// Used for the gemini connection type (primary/default).
final geminiProviderProvider = Provider<AIProvider>((ref) {
  throw UnimplementedError(
    'geminiProviderProvider must be overridden in main.dart',
  );
});

/// Provider-agnostic: returns the currently selected AIProvider
/// based on the stored connection type.
///
/// UPDATED: Gemini type now routes to [GeminiProvider] (native REST API)
/// instead of the broken OpenAI-compatible shim.
/// OpenAI-compatible types still use [OpenAIProvider].
final selectedAIProviderProvider = Provider<AIProvider>((ref) {
  final storage = ref.watch(aiConnectionStorageProvider);
  final connectionType = storage.getConnectionType();

  switch (connectionType) {
    case ConnectionType.gemini:
      // Primary/default: use native Gemini provider, wrapped with AUTO
      // model self-healing (rediscover + retry-once on model-not-found).
      return AutoModelProvider(
        inner: ref.watch(geminiProviderProvider),
        storage: storage,
        preferenceOrder: ModelSelector.geminiPreferenceOrder,
      );
    case ConnectionType.openaiCompatible:
    case ConnectionType.customOpenAI:
      // Secondary: use OpenAI-compatible provider, wrapped with AUTO
      // model self-healing.
      return AutoModelProvider(
        inner: ref.watch(openaiProviderProvider),
        storage: storage,
        preferenceOrder: ModelSelector.openAIPreferenceOrder,
      );
  }
});

/// Provider for [DeviceServiceImpl].
final deviceServiceProvider = Provider<DeviceServiceImpl>((ref) {
  return DeviceServiceImpl();
});

/// Stream provider for connectivity status.
final connectionStatusStreamProvider = StreamProvider<bool>((ref) {
  final deviceService = ref.watch(deviceServiceProvider);
  return deviceService.onConnectivityChanged;
});

/// Provider for [MemoryDatabase].
final memoryDatabaseProvider = Provider<MemoryDatabase>((ref) {
  return MemoryDatabase();
});

/// Provider for [MemoryRepositoryImpl].
final memoryRepositoryProvider = Provider<MemoryRepositoryImpl>((ref) {
  return MemoryRepositoryImpl(database: ref.watch(memoryDatabaseProvider));
});

/// Provider for the [MemoryService] (via MemoryRepositoryImpl).
final memoryServiceProvider = Provider<MemoryService>((ref) {
  return ref.watch(memoryRepositoryProvider).memoryService;
});

/// Provider for default [AgentConfig] entity.
final agentConfigEntityProvider = FutureProvider<AgentConfig>((ref) async {
  final repo = ref.watch(agentConfigRepositoryProvider);
  final configs = repo.getAllAgentConfigs();
  if (configs.isNotEmpty) {
    return configs.first;
  }
  // Fallback default agent config — now using Gemini model.
  return const AgentConfig(
    id: 'default',
    name: 'TEXO',
    description: 'یاریدەدەری تایبەتی تۆ',
    systemPrompt:
        'من تێکسۆی تایبەتی تۆم. وەلامی کوردی سۆرانی بدەرەوە.',
    modelId: 'gemini-3.6-flash',
    temperature: 0.7,
    maxTokens: 2048,
    isDefault: true,
    isActive: true,
  );
});

/// Provider for [DeviceChannel].
///
/// Returns [AndroidDeviceChannel] on Android and [StubDeviceChannel]
/// on all other platforms (iOS, web, desktop), ensuring graceful
/// fallback with `platformUnsupported` error codes.
final deviceChannelProvider = Provider<DeviceChannel>((ref) {
  if (Platform.isAndroid) {
    return AndroidDeviceChannel();
  }
  return StubDeviceChannel(
    platformLabel: Platform.operatingSystem,
  );
});

/// Phase 6 provider for [SystemControlChannel].
///
/// Returns [AndroidSystemControlChannel] on Android and
/// [StubSystemControlChannel] (fail-closed) on every other platform.
/// Kept separate from [deviceChannelProvider] so the existing
/// [DeviceChannel] contract and its many implementers stay untouched.
final systemControlChannelProvider = Provider<SystemControlChannel>((ref) {
  if (Platform.isAndroid) {
    return AndroidSystemControlChannel();
  }
  return StubSystemControlChannel(
    platformLabel: Platform.operatingSystem,
  );
});

/// Provider for [ToolRegistry] with all tools registered.
final toolRegistryProvider = Provider<ToolRegistry>((ref) {
  final registry = ToolRegistry();
  // ── Alarm tools (all backed by the real AlarmSchedulerService) ──
  final alarmGateway = ref.watch(alarmToolGatewayProvider);
  registry.register(CreateAlarmTool(alarmGateway));
  registry.register(ListAlarmsTool(alarmGateway));
  registry.register(UpdateAlarmTool(alarmGateway));
  registry.register(DeleteAlarmTool(alarmGateway));
  registry.register(SetAlarmTool(alarmGateway));
  // ── Vision tools ──
  final visionService = ref.watch(visionServiceProvider);
  registry.register(AnalyzeVisionTool(visionService));
  registry.register(FindObjectTool(visionService));
  registry.register(ReadTextTool(visionService));
  registry.register(LocateTargetTool(visionService));
  registry.register(OpenCameraTool(ref.watch(visionCameraServiceProvider)));
  // ── Device tools ──
  final deviceChannel = ref.watch(deviceChannelProvider);
  registry.register(DeviceInfoTool(deviceChannel));
  registry.register(BatteryTool(deviceChannel));
  registry.register(NetworkTool(deviceChannel));
  registry.register(AppLaunchTool(deviceChannel));
  registry.register(SystemSettingsTool(deviceChannel));
  registry.register(UrlLaunchTool(deviceChannel));
  // ── Phase 6 capability tools (production tool path) ──
  // All route through Agent → ToolSecurityGate → ConfirmationGuard →
  // executor → verified result, exactly like the existing device tools.
  final systemControl = ref.watch(systemControlChannelProvider);
  registry.register(BluetoothControlTool(systemControl));
  registry.register(WifiControlTool(systemControl));
  registry.register(ResourceOptimizationTool(systemControl));
  registry.register(ScreenGestureTool(systemControl));
  // Translation reuses the already-wired AI provider (no new keys/network).
  registry.register(TranslateTextTool(ref.watch(selectedAIProviderProvider)));
  return registry;
});

/// Synchronous provider for the current [AgentConfig] entity.
/// Initialized with a default config; can be updated from the repository.
final agentConfigProvider = StateProvider<AgentConfig>((ref) {
  // Start with default config; when agentConfigEntityProvider resolves,
  // update this.
  ref.listen(agentConfigEntityProvider, (_, next) {
    next.whenData((config) {
      // ignore: deprecated_member_use_from_same_package
      ref.controller.state = config;
    });
  });
  return const AgentConfig(
    id: 'default',
    name: 'TEXO',
    description: 'یاریدەدەری تایبەتی تۆ',
    systemPrompt:
        'من تێکسۆی تایبەتی تۆم. وەلامی کوردی سۆرانی بدەرەوە.',
    modelId: 'gemini-3.6-flash',
    temperature: 0.7,
    maxTokens: 2048,
    isDefault: true,
    isActive: true,
  );
});

// ── Semantic Memory Providers (Phase 1 wiring) ────────────────────────

/// Semantic memory manager — delegates to [semantic_memory.memoryManagerProvider].
///
/// Uses `semantic_memory` prefix to avoid collision with the core
/// [memoryRepositoryProvider] (which is [MemoryRepositoryImpl] for
/// conversation persistence, not semantic memory).
final semanticMemoryManagerProvider = Provider<MemoryManager>(
  (ref) => ref.watch(semantic_memory.memoryManagerProvider),
  name: 'semanticMemoryManager',
);

/// Semantic memory integration — delegates to [semantic_memory.memoryIntegrationProvider].
///
/// Provides [AgentMemoryIntegration] for context enrichment and conversation capture.
final semanticMemoryIntegrationProvider = Provider<AgentMemoryIntegration>(
  (ref) => ref.watch(semantic_memory.memoryIntegrationProvider),
  name: 'semanticMemoryIntegration',
);

/// Semantic memory state — alias for [semantic_memory.memoryStateProvider].
///
/// Provides [MemoryState] for UI observation of semantic memory.
final semanticMemoryStateProvider =
    semantic_memory.memoryStateProvider;

/// Provider for [AgentEngine] wired with the sendToAI adapter.
/// Now uses [selectedAIProviderProvider] for provider-agnostic routing.
///
/// Phase 1 wiring: includes [onMemoryEnrichment] and [onMemoryCapture]
/// callbacks that integrate semantic memory into the agent lifecycle.
final agentEngineProvider = Provider<AgentEngine>((ref) {
  final toolRegistry = ref.watch(toolRegistryProvider);
  final aiProvider = ref.watch(selectedAIProviderProvider);
  final securityGate = ref.watch(toolSecurityGateProvider);
  final memoryIntegration = ref.read(semanticMemoryIntegrationProvider);

  return AgentEngine(
    toolRegistry: toolRegistry,
    securityGate: securityGate,
    onSecurityConfirmation: (request) =>
        ref.read(securityConfirmationProvider.notifier).request(request),
    sendToAI: ({
      required List<Map<String, dynamic>> messages,
      required List<Map<String, dynamic>> toolDefinitions,
      required AgentContext context,
    }) {
      return sendToAIAdapter(
        messages: messages,
        toolDefinitions: toolDefinitions,
        context: context,
        aiProvider: aiProvider,
      );
    },
    // ── Phase 1: Memory enrichment before _understand() ─────────────
    // Recall relevant memories and inject them into the context
    // as a system message. Uses AgentContextAdapter to bridge
    // AgentContext ↔ AgentContextView interface mismatch.
    onMemoryEnrichment: (String userInput, AgentContext context) async {
      try {
        final adapter = AgentContextAdapter(context);
        final enrichResult = await memoryIntegration.enrichContext(
          context: adapter,
          userQuery: userInput,
        );
        if (enrichResult.isSuccess) {
          return adapter.currentContext;
        }
        // Enrichment failed (non-fatal) — return original context.
        return context;
      } catch (e) {
        // Never let memory issues crash the agent.
        return context;
      }
    },
    // ── Phase 1: Memory capture after successful run ─────────────────
    // Extract memorable information from the conversation.
    // Fire-and-forget with error swallowing.
    onMemoryCapture: (String userInput, AgentContext context) async {
      try {
        final adapter = AgentContextAdapter(context);
        await memoryIntegration.captureFromConversation(
          history: adapter.history,
        );
      } catch (e) {
        // Never let memory capture failure affect agent results.
      }
    },
  );
});

// ═════════════════════════════════════════════════════════════════════
// Orchestration (Step 23) — Adapter → Repository → Orchestrator wiring
// ═════════════════════════════════════════════════════════════════════
//
// Every provider below is typed as a *repository interface* (never a
// concrete adapter), honouring the Dependency Inversion boundary that
// AgentOrchestrator + OrchestrationProviders now enforce. Each adapter
// is injected with the SAME canonical subsystem instance the rest of the
// app already uses (toolRegistryProvider, securityPolicyProvider,
// permissionServiceProvider, confirmationGuardProvider, deviceServiceProvider,
// memoryContextProvider) — no competing singletons are created.
//
// FAIL-CLOSED behaviour lives inside each adapter; this file only wires.

/// Shared cancellation token for the orchestration execution engine.
/// Kept as a single instance so the executor and the ToolExecutionAdapter
/// observe the same cancellation state.
final orchestrationCancellationTokenProvider =
    Provider<CancellationToken>((ref) => CancellationToken());

/// Real Step 22 [AgentExecutor] for the orchestration execution phase,
/// wired with the SAME [toolRegistryProvider] and [toolSecurityGateProvider]
/// the AgentEngine uses. Every orchestration tool call therefore passes
/// through the full ToolSecurityGate pipeline (allowlist → sanitise →
/// validate → security boundary → permission → risk → confirmation).
final orchestrationAgentExecutorProvider = Provider<AgentExecutor>((ref) {
  return AgentExecutor(
    toolRegistry: ref.watch(toolRegistryProvider),
    securityGate: ref.watch(toolSecurityGateProvider),
    onSecurityConfirmation: (request) =>
        ref.read(securityConfirmationProvider.notifier).request(request),
    cancellationToken: ref.watch(orchestrationCancellationTokenProvider),
  );
});

/// Step 18 recovery-decision module used by the RecoveryAdapter.
final orchestrationRecoveryEngineProvider =
    Provider<core_recovery.AgentRecovery>(
        (ref) => core_recovery.AgentRecovery());

/// AppLocalizationService for the orchestration layer (Kurdish Sorani first).
final orchestrationLocalizationProvider =
    Provider<AppLocalizationService>((ref) => AppLocalizationService());

// ── Repository-interface providers (concrete adapters hidden behind them) ──

/// AgentEngineRepository — wired to the canonical Step 16 AgentEngine.
/// The adapter exposes the existing understand/plan seams without
/// executing AgentEngine.run() or creating a second engine.
final orchestrationAgentEngineRepositoryProvider =
    Provider<AgentEngineRepository>(
  (ref) => orch.AgentEngineAdapter(
    agentEngine: ref.watch(agentEngineProvider),
  ),
);

/// MemoryRepository — reuses the Phase 1 [memoryContextProvider].
final orchestrationMemoryRepositoryProvider =
    Provider<MemoryRepository>(
        (ref) => orch.MemoryAdapter(ref.watch(memoryContextProvider)));

/// ToolRegistryRepository — reuses the canonical [toolRegistryProvider].
final orchestrationToolRegistryRepositoryProvider =
    Provider<ToolRegistryRepository>(
        (ref) => orch.ToolRegistryAdapter(ref.watch(toolRegistryProvider)));

/// SecurityRepository — real SecurityPolicy + canonical registry allowlist.
final orchestrationSecurityRepositoryProvider =
    Provider<SecurityRepository>((ref) => orch.SecurityAdapter(
          ref.watch(securityPolicyProvider),
          ref.watch(toolRegistryProvider),
        ));

/// PermissionRepository — real Step 16 PermissionService + SecurityPolicy
/// permission resolution + canonical registry.
final orchestrationPermissionRepositoryProvider =
    Provider<PermissionRepository>((ref) => orch.PermissionAdapter(
          ref.watch(permissionServiceProvider),
          ref.watch(securityPolicyProvider),
          ref.watch(toolRegistryProvider),
        ));

/// ConfirmationRepository — real Step 20 ConfirmationGuard.
final orchestrationConfirmationRepositoryProvider =
    Provider<ConfirmationRepository>(
        (ref) => orch.ConfirmationAdapter(ref.watch(confirmationGuardProvider)));

/// ToolExecutionRepository — real Step 22 AgentExecutor + shared token.
final orchestrationToolExecutionRepositoryProvider =
    Provider<ToolExecutionRepository>((ref) => orch.ToolExecutionAdapter(
          ref.watch(orchestrationAgentExecutorProvider),
          ref.watch(orchestrationCancellationTokenProvider),
        ));

/// RecoveryRepository — real Step 18 AgentRecovery decision module.
final orchestrationRecoveryRepositoryProvider =
    Provider<RecoveryRepository>((ref) =>
        orch.RecoveryAdapter(ref.watch(orchestrationRecoveryEngineProvider)));

/// ConnectivityRepository — reuses the canonical [deviceServiceProvider].
final orchestrationConnectivityRepositoryProvider =
    Provider<ConnectivityRepository>(
        (ref) => orch.ConnectivityAdapter(ref.watch(deviceServiceProvider)));

/// AuditRepository — Class D (in-memory ring; no persistent audit sink
/// exists yet, see report). Isolated per-container instance.
final orchestrationAuditRepositoryProvider =
    Provider<AuditRepository>((ref) => orch.AuditAdapter());

// ── Factory + composed graph ──

/// The pure [OrchestrationProviders] factory (interface-typed params).
final orchestrationProvidersProvider =
    Provider<OrchestrationProviders>((ref) => OrchestrationProviders());

/// Fully-wired [AgentOrchestrator] built from the repository providers.
final agentOrchestratorProvider = Provider<AgentOrchestrator>((ref) {
  final factory = ref.watch(orchestrationProvidersProvider);
  return factory.createOrchestrator(
    agentEngine: ref.watch(orchestrationAgentEngineRepositoryProvider),
    memory: ref.watch(orchestrationMemoryRepositoryProvider),
    toolRegistry: ref.watch(orchestrationToolRegistryRepositoryProvider),
    security: ref.watch(orchestrationSecurityRepositoryProvider),
    permission: ref.watch(orchestrationPermissionRepositoryProvider),
    confirmation: ref.watch(orchestrationConfirmationRepositoryProvider),
    execution: ref.watch(orchestrationToolExecutionRepositoryProvider),
    recovery: ref.watch(orchestrationRecoveryRepositoryProvider),
    connectivity: ref.watch(orchestrationConnectivityRepositoryProvider),
    audit: ref.watch(orchestrationAuditRepositoryProvider),
    localization: ref.watch(orchestrationLocalizationProvider),
  );
});

/// [OrchestrationUseCase] wrapping the wired orchestrator.
final orchestrationUseCaseProvider = Provider<OrchestrationUseCase>((ref) {
  final factory = ref.watch(orchestrationProvidersProvider);
  return factory.createUseCase(
    orchestrator: ref.watch(agentOrchestratorProvider),
  );
});

// ═════════════════════════════════════════════════════════════════════
// Trigger Integration (Step 24) — runtime wiring
// ═════════════════════════════════════════════════════════════════════
//
// Runtime chain:
//
// TriggerPlatformService
//        ↓
// TriggerRuntimeService
//        ↓
// TriggerController
//        ↓
// TriggerRouter
//        ↓
// TriggerOrchestrationAdapter
//        ↓
// OrchestrationUseCase
//        ↓
// AgentOrchestrator
//        ↓
// canonical AgentEngine
//
// The platform service remains transport-only. The runtime service is
// responsible for consuming pending Android → Flutter trigger requests.

/// Step 24 Trigger authorization repository.
///
/// SecurityBridgeAdapter is currently the fail-closed authorization
/// boundary for Trigger Integration. Its internal security integration
/// will be upgraded separately to use the canonical security services.
final triggerAuthorizationRepositoryProvider =
    Provider<trigger_auth.TriggerAuthorizationRepository>((ref) {
  return SecurityBridgeAdapter();
});

/// Real Step 24 orchestration bridge.
final triggerOrchestrationAdapterProvider =
    Provider<TriggerOrchestrationAdapter>((ref) {
  return TriggerOrchestrationAdapter(
    orchestrationUseCase: ref.watch(orchestrationUseCaseProvider),
  );
});

/// Real Step 24 TriggerController composed from the authorization and
/// orchestration layers.
final triggerControllerProvider = Provider<TriggerController>((ref) {
  return TriggerProviders.createController(
    authorizationRepository:
        ref.watch(triggerAuthorizationRepositoryProvider),
    orchestrationAdapter:
        ref.watch(triggerOrchestrationAdapterProvider),
    defaultLocale: 'ku',
  );
});

/// Dedicated Android ↔ Flutter trigger transport.
final triggerPlatformServiceProvider =
    Provider<TriggerPlatformService>((ref) {
  final service = TriggerPlatformService();
  ref.onDispose(service.dispose);
  return service;
});

/// Runtime consumer that drains platform pending requests and sends
/// them through the real TriggerController.
final deviceIntegrationControllerProvider =
    device_integration.deviceIntegrationControllerProvider;

final triggerRuntimeServiceProvider =
    Provider<TriggerRuntimeService>((ref) {
  final service = TriggerRuntimeService(
    platform: ref.watch(triggerPlatformServiceProvider),
    controller: ref.watch(triggerControllerProvider),
  );

  ref.onDispose(service.dispose);
  return service;
});
