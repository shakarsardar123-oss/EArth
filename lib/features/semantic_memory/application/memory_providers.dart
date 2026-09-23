/// memory_providers.dart
/// AURA Assistant – Step 17: Semantic Memory
///
/// Riverpod provider definitions for the semantic memory feature.
/// Follows the CentralPermissionProviderNames pattern:
///   - Abstract class with static const String name constants
///   - Type constants for provider references
///   - Type aliases
/// Kurdish-first, local-first, privacy-conscious.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/memory_entry.dart';
import '../domain/models/memory_failure.dart';
import '../domain/models/memory_type.dart';
import '../domain/repositories/memory_repository.dart';
import '../domain/services/memory_embedding_service.dart';
import '../domain/services/memory_storage_service.dart';
import '../infrastructure/local_memory_storage_service.dart';
import '../infrastructure/memory_repository_impl.dart';
import '../infrastructure/hashing_embedding_service.dart';
import '../infrastructure/vector_search_service.dart';
import 'agent_memory_integration.dart';
import 'memory_manager.dart';
import 'memory_policy.dart';
import 'memory_state.dart';
import '../../../core/errors/result.dart';

/// Provider name constants for the semantic memory feature.
///
/// Follows the CentralPermissionProviderNames pattern.
abstract class MemoryProviderNames {
  // ─── Service names ───────────────────────────────────────────────
  static const String storageService = 'memory_storage_service';
  static const String embeddingService = 'memory_embedding_service';
  static const String vectorSearchService = 'memory_vector_search_service';
  static const String repository = 'memory_repository';
  static const String policy = 'memory_policy';
  static const String manager = 'memory_manager';
  static const String integration = 'memory_integration';
  static const String state = 'memory_state';

  // ─── Provider type constants ─────────────────────────────────────
  static const Type storageServiceType = MemoryStorageService;
  static const Type embeddingServiceType = MemoryEmbeddingService;
  static const Type vectorSearchServiceType = VectorSearchService;
  static const Type repositoryType = MemoryRepository;
  static const Type policyType = MemoryPolicy;
  static const Type managerType = MemoryManager;
  static const Type integrationType = AgentMemoryIntegration;
  static const Type stateType = MemoryState;
}

// ─── Type aliases ──────────────────────────────────────────────────

typedef MemoryStateProvider
    = StateNotifierProvider<MemoryStateNotifier, MemoryState>;

// ─── Concrete providers ────────────────────────────────────────────

/// Storage service provider (local in-memory implementation).
final memoryStorageServiceProvider = Provider<MemoryStorageService>(
  (ref) => LocalMemoryStorageService(),
  name: MemoryProviderNames.storageService,
);

/// Embedding service provider (stub implementation).
final memoryEmbeddingServiceProvider = Provider<MemoryEmbeddingService>(
  (ref) => HashingEmbeddingService(),
  name: MemoryProviderNames.embeddingService,
);

/// Vector search service provider.
final memoryVectorSearchServiceProvider = Provider<VectorSearchService>(
  (ref) => VectorSearchService(),
  name: MemoryProviderNames.vectorSearchService,
);

/// Repository provider (combines storage + embedding + search).
final memoryRepositoryProvider = Provider<MemoryRepository>(
  (ref) => MemoryRepositoryImpl(
    storage: ref.watch(memoryStorageServiceProvider),
    embedding: ref.watch(memoryEmbeddingServiceProvider),
    vectorSearch: ref.watch(memoryVectorSearchServiceProvider),
  ),
  name: MemoryProviderNames.repository,
);

/// Memory policy provider.
final memoryPolicyProvider = Provider<MemoryPolicy>(
  (ref) => MemoryPolicy(),
  name: MemoryProviderNames.policy,
);

/// Memory manager provider (application service).
final memoryManagerProvider = Provider<MemoryManager>(
  (ref) => MemoryManager(
    repository: ref.watch(memoryRepositoryProvider),
    policy: ref.watch(memoryPolicyProvider),
  ),
  name: MemoryProviderNames.manager,
);

/// Agent memory integration provider.
final memoryIntegrationProvider = Provider<AgentMemoryIntegration>(
  (ref) => AgentMemoryIntegration(
    memoryManager: ref.watch(memoryManagerProvider),
    policy: ref.watch(memoryPolicyProvider),
  ),
  name: MemoryProviderNames.integration,
);

/// Memory state notifier.
class MemoryStateNotifier extends StateNotifier<MemoryState> {
  final MemoryManager _manager;

  MemoryStateNotifier(this._manager) : super(const MemoryState());

  /// Load all memories into state.
  Future<void> loadMemories() async {
    state = state.copyWith(isLoading: true, clearFailure: true);
    final result = await _manager.list();
    if (result.isError) {
      state = state.copyWith(
        isLoading: false,
        failure: result.error!,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        memories: result.value!,
        totalCount: result.value!.length,
      );
    }
  }

  /// Search memories.
  Future<void> search(String query) async {
    state = state.copyWith(
      isLoading: true,
      searchQuery: query,
      clearFailure: true,
    );
    final result = await _manager.search(query: query);
    if (result.isError) {
      state = state.copyWith(
        isLoading: false,
        failure: result.error!,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        searchResults: result.value!,
      );
    }
  }

  /// Clear search results.
  void clearSearch() {
    state = state.copyWith(
      clearSearchQuery: true,
      searchResults: const [],
    );
  }

  /// Set type filter.
  void setFilter(MemoryType? type) {
    state = state.copyWith(filterType: type);
  }

  /// Select a memory.
  void selectMemory(MemoryEntry? entry) {
    if (entry == null) {
      state = state.copyWith(clearSelectedMemory: true);
    } else {
      state = state.copyWith(selectedMemory: entry);
    }
  }

  /// Forget a memory and reload.
  Future<void> forgetMemory(String id) async {
    state = state.copyWith(isLoading: true, clearFailure: true);
    final result = await _manager.forget(id);
    if (result.isError) {
      state = state.copyWith(isLoading: false, failure: result.error!);
    } else {
      await loadMemories();
    }
  }

  /// Remember a new memory.
  Future<void> rememberMemory({
    required String content,
    required MemoryType type,
    double? importance,
  }) async {
    state = state.copyWith(isLoading: true, clearFailure: true);
    final result = await _manager.remember(
      content: content,
      type: type,
      importance: importance,
    );
    if (result.isError) {
      state = state.copyWith(isLoading: false, failure: result.error!);
    } else {
      await loadMemories();
    }
  }
}

/// Memory state notifier provider.
final memoryStateProvider = StateNotifierProvider<MemoryStateNotifier, MemoryState>(
  (ref) => MemoryStateNotifier(ref.watch(memoryManagerProvider)),
  name: MemoryProviderNames.state,
);
