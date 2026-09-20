/// tool_registry_provider_names.dart
/// AURA Assistant – Step 20: Tool Registry & Allowlist
///
/// Provider names for Riverpod integration.
/// Follows the established pattern: abstract class with static const
/// String name + static const Type type → StateNotifierProvider.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aura_assistant/features/tool_registry/presentation/tool_registry_state_notifier.dart';
import 'package:aura_assistant/features/tool_registry/domain/models/models.dart';
import 'package:aura_assistant/features/tool_registry/infrastructure/infrastructure.dart';

/// Provider names for the Tool Registry feature.
///
/// Each provider has a [name] (String) and a [type] (Type) that together
/// define a Riverpod [StateNotifierProvider].
abstract class ToolRegistryProviderNames {
  // ─── Core Providers ──────────────────────────────────────────

  /// Main [ToolRegistryStateNotifier] provider.
  static const String toolRegistryStateName = 'toolRegistryState';
  static const Type toolRegistryStateType = ToolRegistryStateNotifier;

  /// [ToolRegistryService] provider.
  static const String toolRegistryServiceName = 'toolRegistryService';
  static const Type toolRegistryServiceType = ToolRegistryService;

  /// [ToolConfirmationService] provider.
  static const String toolConfirmationServiceName = 'toolConfirmationService';
  static const Type toolConfirmationServiceType = ToolConfirmationService;

  /// [ToolExecutionGate] provider.
  static const String toolExecutionGateName = 'toolExecutionGate';
  static const Type toolExecutionGateType = ToolExecutionGate;

  /// [ToolDiscoveryApi] provider.
  static const String toolDiscoveryApiName = 'toolDiscoveryApi';
  static const Type toolDiscoveryApiType = ToolDiscoveryApi;

  // ─── Adapter Providers ────────────────────────────────────────

  /// [ToolSecurityAdapter] provider.
  static const String toolSecurityAdapterName = 'toolSecurityAdapter';
  static const Type toolSecurityAdapterType = ToolSecurityAdapter;

  /// [ToolPermissionAdapter] provider.
  static const String toolPermissionAdapterName = 'toolPermissionAdapter';
  static const Type toolPermissionAdapterType = ToolPermissionAdapter;

  /// [ToolRecoveryAdapter] provider.
  static const String toolRecoveryAdapterName = 'toolRecoveryAdapter';
  static const Type toolRecoveryAdapterType = ToolRecoveryAdapter;

  /// [ToolMemoryAdapter] provider.
  static const String toolMemoryAdapterName = 'toolMemoryAdapter';
  static const Type toolMemoryAdapterType = ToolMemoryAdapter;

  // ─── Derived Providers ────────────────────────────────────────

  /// Provider for the list of registered tool IDs.
  static const String registeredToolIdsName = 'registeredToolIds';
  static const Type registeredToolIdsType = List<String>;

  /// Provider for the list of allowed tool IDs.
  static const String allowedToolIdsName = 'allowedToolIds';
  static const Type allowedToolIdsType = List<String>;

  /// Provider for the list of available categories.
  static const String availableCategoriesName = 'availableCategories';
  static const Type availableCategoriesType = List<ToolCategory>;

  /// Provider for whether the registry is in offline mode.
  static const String isOfflineName = 'toolRegistryIsOffline';
  static const Type isOfflineType = bool;
}

/// Concrete Riverpod providers for the Tool Registry feature.
///
/// These are the actual [Provider] instances that can be used in the app.
class ToolRegistryProviders {
  ToolRegistryProviders._();

  /// Default [DefaultToolRegistryService] provider.
  static final toolRegistryServiceProvider = Provider<ToolRegistryService>(
    (ref) => DefaultToolRegistryService(),
    name: ToolRegistryProviderNames.toolRegistryServiceName,
  );

  /// Default [DefaultToolConfirmationService] provider.
  static final toolConfirmationServiceProvider =
      Provider<ToolConfirmationService>(
    (ref) => DefaultToolConfirmationService(),
    name: ToolRegistryProviderNames.toolConfirmationServiceName,
  );

  /// [ToolSecurityAdapter] provider (optional, defaults to null).
  static final toolSecurityAdapterProvider =
      Provider<ToolSecurityAdapter?>((ref) => null);

  /// [ToolPermissionAdapter] provider (optional, defaults to null).
  static final toolPermissionAdapterProvider =
      Provider<ToolPermissionAdapter?>((ref) => null);

  /// [ToolRecoveryAdapter] provider (optional, defaults to null).
  static final toolRecoveryAdapterProvider =
      Provider<ToolRecoveryAdapter?>((ref) => null);

  /// [ToolMemoryAdapter] provider (optional, defaults to null).
  static final toolMemoryAdapterProvider =
      Provider<ToolMemoryAdapter?>((ref) => null);

  /// [DefaultToolExecutionGate] provider.
  static final toolExecutionGateProvider = Provider<ToolExecutionGate>(
    (ref) {
      final registryService = ref.watch(toolRegistryServiceProvider);
      final confirmationService = ref.watch(toolConfirmationServiceProvider);
      final securityAdapter = ref.watch(toolSecurityAdapterProvider);
      final permissionAdapter = ref.watch(toolPermissionAdapterProvider);
      final recoveryAdapter = ref.watch(toolRecoveryAdapterProvider);
      final memoryAdapter = ref.watch(toolMemoryAdapterProvider);

      return DefaultToolExecutionGate(
        registryService: registryService,
        confirmationService: confirmationService,
        securityAdapter: securityAdapter,
        permissionAdapter: permissionAdapter,
        recoveryAdapter: recoveryAdapter,
        memoryAdapter: memoryAdapter,
      );
    },
    name: ToolRegistryProviderNames.toolExecutionGateName,
  );

  /// [DefaultToolDiscoveryApi] provider.
  static final toolDiscoveryApiProvider = Provider<ToolDiscoveryApi>(
    (ref) {
      final registryService = ref.watch(toolRegistryServiceProvider);
      return DefaultToolDiscoveryApi(registryService: registryService);
    },
    name: ToolRegistryProviderNames.toolDiscoveryApiName,
  );

  /// Main [ToolRegistryStateNotifier] provider.
  static final toolRegistryStateProvider =
      StateNotifierProvider<ToolRegistryStateNotifier, ToolState>(
    (ref) {
      final registryService = ref.watch(toolRegistryServiceProvider);
      final confirmationService = ref.watch(toolConfirmationServiceProvider);
      final executionGate = ref.watch(toolExecutionGateProvider);
      final discoveryApi = ref.watch(toolDiscoveryApiProvider);

      return ToolRegistryStateNotifier(
        registryService: registryService,
        confirmationService: confirmationService,
        executionGate: executionGate,
        discoveryApi: discoveryApi,
      );
    },
    name: ToolRegistryProviderNames.toolRegistryStateName,
  );

  /// Derived: list of registered tool IDs.
  static final registeredToolIdsProvider = Provider<List<String>>(
    (ref) {
      final state = ref.watch(toolRegistryStateProvider);
      return state.definitions.map((d) => d.toolId).toList();
    },
    name: ToolRegistryProviderNames.registeredToolIdsName,
  );

  /// Derived: list of allowed tool IDs.
  static final allowedToolIdsProvider = Provider<List<String>>(
    (ref) {
      final state = ref.watch(toolRegistryStateProvider);
      return state.allowlistEntries
          .where((e) => e.isAllowed)
          .map((e) => e.toolId)
          .toList();
    },
    name: ToolRegistryProviderNames.allowedToolIdsName,
  );

  /// Derived: available categories.
  static final availableCategoriesProvider = Provider<List<ToolCategory>>(
    (ref) {
      final state = ref.watch(toolRegistryStateProvider);
      final categories = <ToolCategory>{};
      for (final d in state.definitions) {
        categories.add(d.effectiveCategory);
      }
      return categories.toList()
        ..sort((a, b) => a.index.compareTo(b.index));
    },
    name: ToolRegistryProviderNames.availableCategoriesName,
  );

  /// Derived: is offline.
  static final isOfflineProvider = Provider<bool>(
    (ref) {
      final state = ref.watch(toolRegistryStateProvider);
      return state.isOffline;
    },
    name: ToolRegistryProviderNames.isOfflineName,
  );
}
