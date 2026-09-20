/// memory_state_test.dart
/// Structural tests for MemoryState (presentation layer).
library;

import 'package:test/test.dart';

// ─── Inline mirrors for structural testing ─────────────────────────

enum MemoryType { userPreference, personalFact, conversation, task, project, device, location, instruction, other }
enum MemoryFailurePhase { storage, embedding, search, policy, unknown }

class MemoryFailure {
  final MemoryFailurePhase phase;
  final String message;
  MemoryFailure({required this.phase, required this.message});
}

class MemoryEntry {
  final String id; final String content; final MemoryType memoryType;
  final DateTime createdAt; final DateTime updatedAt; final double importance;
  final String source; final List<double>? embedding; final bool isActive;
  const MemoryEntry({
    required this.id, required this.content, required this.memoryType,
    required this.createdAt, required this.updatedAt,
    this.importance = 0.5, this.source = 'unknown', this.embedding, this.isActive = true,
  });
}

/// Mirror of MemoryState.
class MemoryState {
  final List<MemoryEntry> memories;
  final bool isLoading;
  final MemoryFailure? failure;
  final String? searchQuery;
  final MemoryType? typeFilter;
  final bool isAdding;
  final bool isDeleting;

  const MemoryState({
    this.memories = const [],
    this.isLoading = false,
    this.failure,
    this.searchQuery,
    this.typeFilter,
    this.isAdding = false,
    this.isDeleting = false,
  });

  MemoryState copyWith({
    List<MemoryEntry>? memories,
    bool? isLoading,
    MemoryFailure? failure,
    bool clearFailure = false,
    String? searchQuery,
    bool clearSearchQuery = false,
    MemoryType? typeFilter,
    bool clearTypeFilter = false,
    bool? isAdding,
    bool? isDeleting,
  }) => MemoryState(
    memories: memories ?? this.memories,
    isLoading: isLoading ?? this.isLoading,
    failure: clearFailure ? null : (failure ?? this.failure),
    searchQuery: clearSearchQuery ? null : (searchQuery ?? this.searchQuery),
    typeFilter: clearTypeFilter ? null : (typeFilter ?? this.typeFilter),
    isAdding: isAdding ?? this.isAdding,
    isDeleting: isDeleting ?? this.isDeleting,
  );

  bool get hasMemories => memories.isNotEmpty;
  bool get hasFailure => failure != null;
  bool get isSearching => searchQuery != null && searchQuery!.isNotEmpty;
  bool get isFiltering => typeFilter != null;
  int get memoryCount => memories.length;

  List<MemoryEntry> get activeMemories => memories.where((m) => m.isActive).toList();
  List<MemoryEntry> get highImportanceMemories => memories.where((m) => m.importance >= 0.7).toList();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemoryState &&
          _listEquals(memories, other.memories) &&
          isLoading == other.isLoading &&
          failure == other.failure &&
          searchQuery == other.searchQuery &&
          typeFilter == other.typeFilter &&
          isAdding == other.isAdding &&
          isDeleting == other.isDeleting;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(memories), isLoading, failure, searchQuery, typeFilter, isAdding, isDeleting,
  );

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

void main() {
  group('MemoryState', () {
    late DateTime now;
    late MemoryEntry entry1;
    late MemoryEntry entry2;

    setUp(() {
      now = DateTime(2025, 1, 15);
      entry1 = MemoryEntry(
        id: 'e1', content: 'Prefers dark mode', memoryType: MemoryType.userPreference,
        createdAt: now, updatedAt: now, importance: 0.8,
      );
      entry2 = MemoryEntry(
        id: 'e2', content: 'Buy groceries', memoryType: MemoryType.task,
        createdAt: now, updatedAt: now, importance: 0.3, isActive: false,
      );
    });

    test('default state has no memories', () {
      const state = MemoryState();
      expect(state.memories, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.failure, isNull);
      expect(state.isAdding, isFalse);
      expect(state.isDeleting, isFalse);
    });

    test('copyWith preserves unchanged fields', () {
      final state = MemoryState(memories: [entry1], isLoading: true);
      final copied = state.copyWith(isLoading: false);
      expect(copied.memories, [entry1]);
      expect(copied.isLoading, isFalse);
    });

    test('copyWith clearFailure clears failure', () {
      final failure = MemoryFailure(phase: MemoryFailurePhase.storage, message: 'err');
      final state = MemoryState(failure: failure);
      final cleared = state.copyWith(clearFailure: true);
      expect(cleared.failure, isNull);
    });

    test('copyWith clearSearchQuery clears query', () {
      const state = MemoryState(searchQuery: 'test');
      final cleared = state.copyWith(clearSearchQuery: true);
      expect(cleared.searchQuery, isNull);
    });

    test('copyWith clearTypeFilter clears filter', () {
      const state = MemoryState(typeFilter: MemoryType.task);
      final cleared = state.copyWith(clearTypeFilter: true);
      expect(cleared.typeFilter, isNull);
    });

    test('hasMemories getter', () {
      const empty = MemoryState();
      expect(empty.hasMemories, isFalse);

      final withMem = MemoryState(memories: [entry1]);
      expect(withMem.hasMemories, isTrue);
    });

    test('hasFailure getter', () {
      const noFailure = MemoryState();
      expect(noFailure.hasFailure, isFalse);

      final withFailure = MemoryState(
        failure: MemoryFailure(phase: MemoryFailurePhase.storage, message: 'err'),
      );
      expect(withFailure.hasFailure, isTrue);
    });

    test('isSearching getter', () {
      const noQuery = MemoryState();
      expect(noQuery.isSearching, isFalse);

      const withQuery = MemoryState(searchQuery: 'test');
      expect(withQuery.isSearching, isTrue);

      const emptyQuery = MemoryState(searchQuery: '');
      expect(emptyQuery.isSearching, isFalse);
    });

    test('isFiltering getter', () {
      const noFilter = MemoryState();
      expect(noFilter.isFiltering, isFalse);

      const withFilter = MemoryState(typeFilter: MemoryType.task);
      expect(withFilter.isFiltering, isTrue);
    });

    test('memoryCount getter', () {
      const empty = MemoryState();
      expect(empty.memoryCount, 0);

      final with2 = MemoryState(memories: [entry1, entry2]);
      expect(with2.memoryCount, 2);
    });

    test('activeMemories filters inactive', () {
      final state = MemoryState(memories: [entry1, entry2]);
      expect(state.activeMemories, hasLength(1));
      expect(state.activeMemories.first.id, 'e1');
    });

    test('highImportanceMemories filters by importance', () {
      final state = MemoryState(memories: [entry1, entry2]);
      expect(state.highImportanceMemories, hasLength(1));
      expect(state.highImportanceMemories.first.id, 'e1');
    });

    test('equality works correctly', () {
      final a = MemoryState(memories: [entry1], isLoading: false);
      final b = MemoryState(memories: [entry1], isLoading: false);
      expect(a, equals(b));
    });

    test('inequality when fields differ', () {
      const a = MemoryState(isLoading: false);
      const b = MemoryState(isLoading: true);
      expect(a, isNot(equals(b)));
    });
  });
}
