/// memory_entry_test.dart
/// Structural tests for MemoryEntry model.
library;

import 'package:test/test.dart';

// ─── Inline mirror of MemoryEntry for structural testing ────────────
// In the real project: import 'package:aura_assistant/features/semantic_memory/domain/models/memory_entry.dart';

enum MemoryType { userPreference, personalFact, conversation, task, project, device, location, instruction, other }

class MemoryEntry {
  final String id;
  final String content;
  final MemoryType memoryType;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double importance;
  final String source;
  final Map<String, dynamic> metadata;
  final List<double>? embedding;
  final bool isActive;

  const MemoryEntry({
    required this.id,
    required this.content,
    required this.memoryType,
    required this.createdAt,
    required this.updatedAt,
    this.importance = 0.5,
    this.source = 'unknown',
    this.metadata = const {},
    this.embedding,
    this.isActive = true,
  });

  MemoryEntry copyWith({
    String? id,
    String? content,
    MemoryType? memoryType,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? importance,
    String? source,
    Map<String, dynamic>? metadata,
    List<double>? embedding,
    bool? isActive,
    bool clearEmbedding = false,
  }) {
    return MemoryEntry(
      id: id ?? this.id,
      content: content ?? this.content,
      memoryType: memoryType ?? this.memoryType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      importance: importance ?? this.importance,
      source: source ?? this.source,
      metadata: metadata ?? this.metadata,
      embedding: clearEmbedding ? null : (embedding ?? this.embedding),
      isActive: isActive ?? this.isActive,
    );
  }

  bool get isHighImportance => importance >= 0.7;
  bool get isLowImportance => importance <= 0.3;
  bool get isDeactivated => !isActive;
  bool get hasEmbedding => embedding != null;
}

void main() {
  group('MemoryEntry', () {
    late DateTime now;
    late MemoryEntry entry;

    setUp(() {
      now = DateTime(2025, 1, 15, 10, 30);
      entry = MemoryEntry(
        id: 'test-1',
        content: 'User prefers dark mode',
        memoryType: MemoryType.userPreference,
        createdAt: now,
        updatedAt: now,
      );
    });

    test('creates with default values', () {
      expect(entry.id, 'test-1');
      expect(entry.content, 'User prefers dark mode');
      expect(entry.memoryType, MemoryType.userPreference);
      expect(entry.importance, 0.5);
      expect(entry.source, 'unknown');
      expect(entry.metadata, isEmpty);
      expect(entry.embedding, isNull);
      expect(entry.isActive, isTrue);
    });

    test('copyWith preserves unchanged fields', () {
      final copied = entry.copyWith(content: 'Updated content');
      expect(copied.id, entry.id);
      expect(copied.content, 'Updated content');
      expect(copied.memoryType, entry.memoryType);
      expect(copied.importance, entry.importance);
      expect(copied.isActive, entry.isActive);
    });

    test('copyWith with clearEmbedding clears embedding', () {
      final withEmbedding = entry.copyWith(embedding: [0.1, 0.2, 0.3]);
      expect(withEmbedding.hasEmbedding, isTrue);

      final cleared = withEmbedding.copyWith(clearEmbedding: true);
      expect(cleared.hasEmbedding, isFalse);
      expect(cleared.embedding, isNull);
    });

    test('isHighImportance returns true for importance >= 0.7', () {
      expect(entry.isHighImportance, isFalse); // default 0.5

      final high = entry.copyWith(importance: 0.8);
      expect(high.isHighImportance, isTrue);

      final boundary = entry.copyWith(importance: 0.7);
      expect(boundary.isHighImportance, isTrue);
    });

    test('isLowImportance returns true for importance <= 0.3', () {
      final low = entry.copyWith(importance: 0.2);
      expect(low.isLowImportance, isTrue);

      final boundary = entry.copyWith(importance: 0.3);
      expect(boundary.isLowImportance, isTrue);

      expect(entry.isLowImportance, isFalse);
    });

    test('isDeactivated returns true when isActive is false', () {
      expect(entry.isDeactivated, isFalse);

      final deactivated = entry.copyWith(isActive: false);
      expect(deactivated.isDeactivated, isTrue);
      expect(deactivated.isActive, isFalse);
    });

    test('hasEmbedding reflects embedding state', () {
      expect(entry.hasEmbedding, isFalse);

      final withEmb = entry.copyWith(embedding: [1.0, 0.0]);
      expect(withEmb.hasEmbedding, isTrue);
    });

    test('custom values are preserved', () {
      final custom = MemoryEntry(
        id: 'custom-1',
        content: 'Test',
        memoryType: MemoryType.task,
        createdAt: now,
        updatedAt: now,
        importance: 0.9,
        source: 'agent_tool',
        metadata: {'key': 'value'},
        embedding: [0.5, 0.5],
        isActive: false,
      );
      expect(custom.importance, 0.9);
      expect(custom.source, 'agent_tool');
      expect(custom.metadata, {'key': 'value'});
      expect(custom.embedding, [0.5, 0.5]);
      expect(custom.isActive, isFalse);
    });
  });
}
