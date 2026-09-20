/// memory_state.dart
/// AURA Assistant – Step 17: Semantic Memory
///
/// Immutable state object for the semantic memory feature.
/// Follows the CentralPermissionState pattern:
///   - const constructor
///   - copyWith with clear* boolean flags for nullable fields
///   - convenience getters
///   - custom == / hashCode
/// Kurdish-first, local-first, privacy-conscious.
library;

import '../domain/models/memory_entry.dart';
import '../domain/models/memory_failure.dart';
import '../domain/models/memory_type.dart';

/// Immutable state for the semantic memory subsystem.
///
/// Tracks the current memories, loading/failure states, and
/// search/recall results. Designed for use with Riverpod or
/// an imperative controller.
class MemoryState {
  /// All active memories currently loaded.
  final List<MemoryEntry> memories;

  /// The most recent search/recall results.
  final List<MemoryEntry> searchResults;

  /// The current search query string.
  final String? searchQuery;

  /// Currently selected memory type filter.
  final MemoryType? filterType;

  /// Whether an async operation is in progress.
  final bool isLoading;

  /// The most recent failure, if any.
  final MemoryFailure? failure;

  /// Total count of active memories (may differ from memories.length
  /// if pagination is used).
  final int totalCount;

  /// The currently selected memory entry (for detail view).
  final MemoryEntry? selectedMemory;

  const MemoryState({
    this.memories = const [],
    this.searchResults = const [],
    this.searchQuery,
    this.filterType,
    this.isLoading = false,
    this.failure,
    this.totalCount = 0,
    this.selectedMemory,
  });

  /// Create a copy with optional field overrides.
  ///
  /// [clearSearchQuery], [clearFilterType], [clearFailure],
  /// and [clearSelectedMemory] flags set the corresponding
  /// nullable field to null when true, regardless of the
  /// provided value.
  MemoryState copyWith({
    List<MemoryEntry>? memories,
    List<MemoryEntry>? searchResults,
    String? searchQuery,
    MemoryType? filterType,
    bool? isLoading,
    MemoryFailure? failure,
    int? totalCount,
    MemoryEntry? selectedMemory,
    bool clearSearchQuery = false,
    bool clearFilterType = false,
    bool clearFailure = false,
    bool clearSelectedMemory = false,
  }) {
    return MemoryState(
      memories: memories ?? this.memories,
      searchResults: searchResults ?? this.searchResults,
      searchQuery: clearSearchQuery ? null : (searchQuery ?? this.searchQuery),
      filterType: clearFilterType ? null : (filterType ?? this.filterType),
      isLoading: isLoading ?? this.isLoading,
      failure: clearFailure ? null : (failure ?? this.failure),
      totalCount: totalCount ?? this.totalCount,
      selectedMemory: clearSelectedMemory
          ? null
          : (selectedMemory ?? this.selectedMemory),
    );
  }

  // ─── Convenience getters ─────────────────────────────────────────

  /// Whether there is a current failure.
  bool get hasFailure => failure != null;

  /// Whether any memories are loaded.
  bool get hasMemories => memories.isNotEmpty;

  /// Whether search results are available.
  bool get hasSearchResults => searchResults.isNotEmpty;

  /// Whether a search query is active.
  bool get isSearching => searchQuery != null && searchQuery!.isNotEmpty;

  /// Whether a type filter is active.
  bool get hasFilter => filterType != null;

  /// Whether a memory is selected.
  bool get hasSelection => selectedMemory != null;

  /// Memories filtered by type, if a filter is active.
  List<MemoryEntry> get filteredMemories {
    if (filterType == null) return memories;
    return memories.where((m) => m.memoryType == filterType).toList();
  }

  /// Count of high-importance memories.
  int get highImportanceCount =>
      memories.where((m) => m.isHighImportance).length;

  /// Count of inactive (soft-deleted) memories.
  int get inactiveCount =>
      memories.where((m) => m.isDeactivated).length;

  // ─── Equality ────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MemoryState) return false;
    // Deep equality on lists is expensive; use length + first for structural test.
    return other.memories.length == memories.length &&
        other.searchResults.length == searchResults.length &&
        other.searchQuery == searchQuery &&
        other.filterType == filterType &&
        other.isLoading == isLoading &&
        other.failure == failure &&
        other.totalCount == totalCount &&
        other.selectedMemory == selectedMemory;
  }

  @override
  int get hashCode => Object.hash(
        memories.length,
        searchResults.length,
        searchQuery,
        filterType,
        isLoading,
        failure,
        totalCount,
        selectedMemory,
      );

  @override
  String toString() =>
      'MemoryState(memories: ${memories.length}, search: $searchQuery, '
      'filter: $filterType, loading: $isLoading, failure: $failure, '
      'total: $totalCount)';
}
