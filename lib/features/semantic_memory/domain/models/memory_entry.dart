/// memory_entry.dart
/// AURA Assistant – Step 17: Semantic Memory
///
/// Immutable domain model representing a single semantic memory entry.
/// Follows the same value-object conventions used across AURA.
/// Kurdish-first, local-first, privacy-conscious.
library;

import 'memory_type.dart';

/// A single semantic memory entry stored in the vector database.
///
/// Memory entries are the fundamental unit of the semantic memory
/// subsystem. Each entry captures a piece of information the agent
/// has learned or been told, with metadata for search, filtering,
/// and privacy policy enforcement.
///
/// Fields:
/// - [id] – Unique identifier (UUID).
/// - [content] – The textual content of the memory.
/// - [memoryType] – Category of the memory.
/// - [createdAt] – Timestamp when the memory was created.
/// - [updatedAt] – Timestamp when the memory was last updated.
/// - [importance] – Salience score from 0.0 (low) to 1.0 (critical).
/// - [source] – Origin of the memory (e.g. 'user', 'agent', 'system').
/// - [metadata] – Arbitrary key-value metadata attached to the entry.
/// - [embedding] – Optional vector embedding for similarity search.
/// - [isActive] – Whether the memory is currently active (not soft-deleted).
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
    this.source = 'user',
    this.metadata = const {},
    this.embedding,
    this.isActive = true,
  });

  /// Creates a copy of this entry with optional field overrides.
  ///
  /// The [clearEmbedding] flag, when true, sets [embedding] to null
  /// even if the original was non-null.
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

  /// Convenience: whether this entry has a computed embedding.
  bool get hasEmbedding => embedding != null && embedding!.isNotEmpty;

  /// Convenience: whether this entry is considered high-importance (≥ 0.7).
  bool get isHighImportance => importance >= 0.7;

  /// Convenience: whether this entry has been soft-deleted.
  bool get isDeactivated => !isActive;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MemoryEntry &&
        other.id == id &&
        other.content == content &&
        other.memoryType == memoryType &&
        other.importance == importance &&
        other.source == source &&
        other.isActive == isActive;
  }

  @override
  int get hashCode => Object.hash(
        id,
        content,
        memoryType,
        importance,
        source,
        isActive,
      );

  @override
  String toString() =>
      'MemoryEntry(id: $id, type: $memoryType, importance: $importance, '
      'active: $isActive, content: ${content.length > 60 ? '${content.substring(0, 60)}…' : content})';
}
