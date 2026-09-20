/// memory_manager.dart
/// AURA Assistant – Step 17: Semantic Memory
///
/// Application-layer service orchestrating memory operations.
/// Provides remember/recall/search/forget/update with duplicate prevention,
/// privacy policy enforcement, and importance scoring.
/// Follows the imperative controller pattern (not ChangeNotifier).
/// Kurdish-first, local-first, privacy-conscious.
library;

import '../domain/models/memory_entry.dart';
import '../domain/models/memory_failure.dart';
import '../domain/models/memory_type.dart';
import '../domain/repositories/memory_repository.dart';
import 'memory_policy.dart';
import '../../../core/errors/result.dart';

/// Application service for semantic memory operations.
///
/// The [MemoryManager] is the primary API that the agent layer
/// and UI interact with. It adds:
/// - Duplicate prevention via [MemoryRepository.findSimilar]
/// - Privacy policy enforcement via [MemoryPolicy]
/// - Importance scoring heuristics
/// - Convenience methods for remember/recall/search/forget/update
class MemoryManager {
  final MemoryRepository _repository;
  final MemoryPolicy _policy;

  /// Create a memory manager with the given repository and policy.
  MemoryManager({
    required MemoryRepository repository,
    MemoryPolicy? policy,
  })  : _repository = repository,
        _policy = policy ?? MemoryPolicy();

  // ─── Core operations ─────────────────────────────────────────────

  /// Remember a new piece of information.
  ///
  /// Checks privacy policy, then duplicate prevention, then stores.
  /// Returns the stored entry or a failure.
  Future<MemoryResult<MemoryEntry>> remember({
    required String content,
    required MemoryType type,
    double? importance,
    String source = 'user',
    Map<String, dynamic>? metadata,
  }) async {
    // 1. Privacy policy check.
    final policyResult = _policy.check(content);
    if (!policyResult.allowed) {
      return Result.error(MemoryFailure.policy(reason: policyResult.reason!));
    }

    // 2. Duplicate prevention.
    final similarResult = await _repository.findSimilar(
      content: content,
      threshold: 0.92,
      type: type,
    );
    if (similarResult.isSuccess && similarResult.value!.isNotEmpty) {
      // Update existing entry instead of creating a duplicate.
      final existing = similarResult.value!.first;
      final updated = existing.copyWith(
        content: content,
        memoryType: type,
        importance: importance ?? existing.importance,
        source: source,
        metadata: metadata ?? existing.metadata,
        updatedAt: DateTime.now(),
      );
      return _repository.update(updated);
    }

    // 3. Create and store new entry.
    final now = DateTime.now();
    final entry = MemoryEntry(
      id: _generateId(),
      content: content,
      memoryType: type,
      createdAt: now,
      updatedAt: now,
      importance: importance ?? _inferImportance(content, type),
      source: source,
      metadata: metadata ?? {},
    );
    return _repository.store(entry);
  }

  /// Recall memories relevant to a query.
  ///
  /// Performs semantic search. Returns up to [limit] entries.
  Future<MemoryResult<List<MemoryEntry>>> recall({
    required String query,
    int limit = 10,
    double minScore = 0.3,
    MemoryType? type,
  }) async {
    return _repository.search(
      query: query,
      limit: limit,
      minScore: minScore,
      type: type,
    );
  }

  /// Search memories by keyword/semantic query.
  ///
  /// Alias for [recall] with different defaults for broader results.
  Future<MemoryResult<List<MemoryEntry>>> search({
    required String query,
    int limit = 20,
    double minScore = 0.2,
    MemoryType? type,
  }) async {
    return _repository.search(
      query: query,
      limit: limit,
      minScore: minScore,
      type: type,
    );
  }

  /// Forget (soft-delete) a memory by [id].
  Future<MemoryResult<void>> forget(String id) async {
    return _repository.deactivate(id);
  }

  /// Update an existing memory entry.
  ///
  /// Looks up the existing entry by [id], merges changes, and persists.
  Future<MemoryResult<MemoryEntry>> update({
    required String id,
    String? content,
    MemoryType? type,
    double? importance,
    String? source,
    Map<String, dynamic>? metadata,
    bool? isActive,
  }) async {
    final existingResult = await _repository.getById(id);
    if (existingResult.isError) {
      return Result.error(existingResult.error!);
    }
    final existing = existingResult.value;
    if (existing == null) {
      return Result.error(MemoryFailure.update(
        idHint: id,
        action: 'not_found',
      ));
    }

    // If content changes, run policy check.
    if (content != null && content != existing.content) {
      final policyResult = _policy.check(content);
      if (!policyResult.allowed) {
        return Result.error(MemoryFailure.policy(reason: policyResult.reason!));
      }
    }

    final updated = existing.copyWith(
      content: content,
      memoryType: type,
      importance: importance,
      source: source,
      metadata: metadata,
      isActive: isActive,
      clearEmbedding: content != null && content != existing.content,
      updatedAt: DateTime.now(),
    );

    return _repository.update(updated);
  }

  /// List all active memories, optionally filtered by [type].
  Future<MemoryResult<List<MemoryEntry>>> list({MemoryType? type}) async {
    return _repository.getAll(type: type);
  }

  /// Get a single memory entry by [id].
  Future<MemoryResult<MemoryEntry?>> getById(String id) async {
    return _repository.getById(id);
  }

  /// Count active memories.
  Future<MemoryResult<int>> count({MemoryType? type}) async {
    return _repository.count(type: type);
  }

  /// Clear all memories (use with caution).
  Future<MemoryResult<void>> clearAll() async {
    return _repository.clearAll();
  }

  // ─── Private helpers ──────────────────────────────────────────────

  /// Generate a unique ID for a new memory entry.
  String _generateId() {
    final now = DateTime.now();
    return 'mem_${now.millisecondsSinceEpoch}_${now.microsecond}';
  }

  /// Heuristic importance inference based on content and type.
  ///
  /// - Instructions and personal facts → high (0.8)
  /// - User preferences and projects → medium-high (0.7)
  /// - Tasks → medium (0.6)
  /// - Conversations → medium-low (0.4)
  /// - Device / location / other → low (0.3)
  double _inferImportance(String content, MemoryType type) {
    switch (type) {
      case MemoryType.instruction:
      case MemoryType.personalFact:
        return 0.8;
      case MemoryType.userPreference:
      case MemoryType.project:
        return 0.7;
      case MemoryType.task:
        return 0.6;
      case MemoryType.conversation:
        return 0.4;
      case MemoryType.device:
      case MemoryType.location:
      case MemoryType.other:
        return 0.3;
    }
  }
}
