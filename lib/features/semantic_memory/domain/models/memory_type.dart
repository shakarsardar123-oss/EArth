/// memory_type.dart
/// AURA Assistant – Step 17: Semantic Memory
///
/// Enum of semantic memory categories.
/// Kurdish-first, local-first, privacy-conscious.
library;

/// Categories of semantic memory entries.
///
/// Each [MemoryType] describes a domain of information the agent
/// may persist for future recall. Types are used for filtering,
/// prioritisation, and privacy policy decisions.
enum MemoryType {
  /// A user preference (e.g. "I prefer dark mode").
  userPreference,

  /// A personal fact about the user (e.g. "My name is Dilan").
  personalFact,

  /// A conversation summary or notable exchange.
  conversation,

  /// A task-related memory (e.g. "Remind me to buy milk").
  task,

  /// A project or long-term goal memory.
  project,

  /// Device-specific context (e.g. "Phone is Samsung S24").
  device,

  /// A location-related memory (e.g. "I live in Erbil").
  location,

  /// An explicit instruction from the user (e.g. "Always answer in Kurdish").
  instruction,

  /// Any other memory that does not fit the above categories.
  other;

  /// Human-readable label key for localization.
  /// Maps to `memory_type_<name>` in the localization table.
  String get labelKey => 'memory_type_$name';
}
