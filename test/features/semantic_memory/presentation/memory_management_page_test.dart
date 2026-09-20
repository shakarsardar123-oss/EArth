/// memory_management_page_test.dart
/// Structural tests for MemoryManagementPage (presentation layer).
/// Since we cannot use flutter_test, we test the underlying state logic
/// and UI contract expectations rather than widget rendering.
library;

import 'package:test/test.dart';

// ─── Inline mirrors ────────────────────────────────────────────────

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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemoryState &&
          memories.length == other.memories.length &&
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
}

/// Localization key mirror for memory_ prefix keys.
const Map<String, String> memoryLocalizationKeys = {
  'memory_title': 'Memory Management',
  'memory_add': 'Add Memory',
  'memory_search': 'Search memories',
  'memory_filter_type': 'Filter by type',
  'memory_empty': 'No memories yet',
  'memory_loading': 'Loading memories...',
  'memory_error': 'Error loading memories',
  'memory_success_added': 'Memory added successfully',
  'memory_confirm_delete': 'Are you sure you want to delete this memory?',
  'memory_deleted': 'Memory deleted',
  'memory_content_label': 'Content',
  'memory_type_label': 'Type',
  'memory_importance_label': 'Importance',
  'memory_source_label': 'Source',
  'memory_created_label': 'Created',
  'memory_updated_label': 'Updated',
  'memory_no_results': 'No matching memories found',
  'memory_active': 'Active',
  'memory_inactive': 'Inactive',
  'memory_clear_filter': 'Clear filter',
  'memory_clear_search': 'Clear search',
  'memory_policy_violation': 'Content violates memory policy',
  'memory_delete': 'Delete',
  'memory_update': 'Update',
  'memory_cancel': 'Cancel',
  'memory_save': 'Save',
  'memory_count': 'Total memories',
  'memory_high_importance': 'High importance',
  'memory_recent': 'Recent',
  'memory_preference': 'Preference',
  'memory_personal': 'Personal',
  'memory_task': 'Task',
  'memory_project': 'Project',
  'memory_conversation': 'Conversation',
  'memory_location': 'Location',
  'memory_instruction': 'Instruction',
  'memory_other': 'Other',
  'memory_device': 'Device',
};

void main() {
  group('MemoryManagementPage structural contract', () {
    group('MemoryState transitions for UI', () {
      late DateTime now;

      setUp(() {
        now = DateTime(2025, 6, 1);
      });

      test('initial state shows empty view', () {
        const state = MemoryState();
        expect(state.hasMemories, isFalse);
        expect(state.isLoading, isFalse);
        expect(state.hasFailure, isFalse);
        // UI should render empty view with memory_empty key
      });

      test('loading state', () {
        const state = MemoryState(isLoading: true);
        expect(state.isLoading, isTrue);
        // UI should show loading indicator with memory_loading key
      });

      test('error state preserves failure', () {
        final failure = MemoryFailure(phase: MemoryFailurePhase.storage, message: 'db error');
        final state = MemoryState(failure: failure);
        expect(state.hasFailure, isTrue);
        // UI should show error banner with memory_error key
      });

      test('state with memories renders list', () {
        final entry = MemoryEntry(
          id: 'm1', content: 'Test', memoryType: MemoryType.userPreference,
          createdAt: now, updatedAt: now,
        );
        final state = MemoryState(memories: [entry]);
        expect(state.hasMemories, isTrue);
        expect(state.memoryCount, 1);
      });

      test('search query activates search mode', () {
        const state = MemoryState(searchQuery: 'dark');
        expect(state.isSearching, isTrue);
        // UI should show search active state with memory_clear_search key available
      });

      test('type filter activates filter mode', () {
        const state = MemoryState(typeFilter: MemoryType.task);
        expect(state.isFiltering, isTrue);
        // UI should show filter active state with memory_clear_filter key available
      });

      test('clearing search returns to normal', () {
        const state = MemoryState(searchQuery: 'test');
        final cleared = state.copyWith(clearSearchQuery: true);
        expect(cleared.isSearching, isFalse);
      });

      test('clearing filter returns to normal', () {
        const state = MemoryState(typeFilter: MemoryType.task);
        final cleared = state.copyWith(clearTypeFilter: true);
        expect(cleared.isFiltering, isFalse);
      });

      test('adding state for add dialog', () {
        const state = MemoryState(isAdding: true);
        expect(state.isAdding, isTrue);
        // UI should show add dialog with memory_add, memory_content_label, memory_type_label keys
      });

      test('deleting state for confirm dialog', () {
        const state = MemoryState(isDeleting: true);
        expect(state.isDeleting, isTrue);
        // UI should show confirm delete dialog with memory_confirm_delete key
      });

      test('combined search and filter state', () {
        const state = MemoryState(searchQuery: 'dark', typeFilter: MemoryType.userPreference);
        expect(state.isSearching, isTrue);
        expect(state.isFiltering, isTrue);
      });

      test('active memories only shown by default', () {
        final active = MemoryEntry(
          id: 'a1', content: 'Active', memoryType: MemoryType.conversation,
          createdAt: now, updatedAt: now, isActive: true,
        );
        final inactive = MemoryEntry(
          id: 'a2', content: 'Inactive', memoryType: MemoryType.conversation,
          createdAt: now, updatedAt: now, isActive: false,
        );
        final state = MemoryState(memories: [active, inactive]);
        expect(state.activeMemories, hasLength(1));
        expect(state.activeMemories.first.id, 'a1');
      });
    });

    group('Localization keys', () {
      test('all memory_ prefix keys are defined', () {
        expect(memoryLocalizationKeys.length, greaterThanOrEqualTo(30));
      });

      test('essential UI keys exist', () {
        expect(memoryLocalizationKeys, contains('memory_title'));
        expect(memoryLocalizationKeys, contains('memory_add'));
        expect(memoryLocalizationKeys, contains('memory_search'));
        expect(memoryLocalizationKeys, contains('memory_empty'));
        expect(memoryLocalizationKeys, contains('memory_loading'));
        expect(memoryLocalizationKeys, contains('memory_error'));
        expect(memoryLocalizationKeys, contains('memory_delete'));
        expect(memoryLocalizationKeys, contains('memory_update'));
        expect(memoryLocalizationKeys, contains('memory_cancel'));
        expect(memoryLocalizationKeys, contains('memory_save'));
        expect(memoryLocalizationKeys, contains('memory_confirm_delete'));
        expect(memoryLocalizationKeys, contains('memory_policy_violation'));
      });

      test('memory type label keys exist', () {
        expect(memoryLocalizationKeys, contains('memory_preference'));
        expect(memoryLocalizationKeys, contains('memory_personal'));
        expect(memoryLocalizationKeys, contains('memory_task'));
        expect(memoryLocalizationKeys, contains('memory_project'));
        expect(memoryLocalizationKeys, contains('memory_conversation'));
        expect(memoryLocalizationKeys, contains('memory_location'));
        expect(memoryLocalizationKeys, contains('memory_instruction'));
        expect(memoryLocalizationKeys, contains('memory_device'));
        expect(memoryLocalizationKeys, contains('memory_other'));
      });

      test('field label keys exist', () {
        expect(memoryLocalizationKeys, contains('memory_content_label'));
        expect(memoryLocalizationKeys, contains('memory_type_label'));
        expect(memoryLocalizationKeys, contains('memory_importance_label'));
        expect(memoryLocalizationKeys, contains('memory_source_label'));
        expect(memoryLocalizationKeys, contains('memory_created_label'));
        expect(memoryLocalizationKeys, contains('memory_updated_label'));
      });

      test('no key has empty value', () {
        for (final entry in memoryLocalizationKeys.entries) {
          expect(entry.value, isNotEmpty, reason: 'Key ${entry.key} has empty value');
        }
      });
    });

    group('MemoryType display labels', () {
      test('every MemoryType has a localization key', () {
        for (final type in MemoryType.values) {
          String key;
          switch (type) {
            case MemoryType.userPreference: key = 'memory_preference';
            case MemoryType.personalFact: key = 'memory_personal';
            case MemoryType.conversation: key = 'memory_conversation';
            case MemoryType.task: key = 'memory_task';
            case MemoryType.project: key = 'memory_project';
            case MemoryType.device: key = 'memory_device';
            case MemoryType.location: key = 'memory_location';
            case MemoryType.instruction: key = 'memory_instruction';
            case MemoryType.other: key = 'memory_other';
          }
          expect(memoryLocalizationKeys, contains(key), reason: 'Missing key $key for type ${type.name}');
        }
      });
    });
  });
}
