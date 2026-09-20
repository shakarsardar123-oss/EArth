/// connection_type.dart
/// AURA Assistant – R7-C: Connection Type Enum
///
/// UPDATED: Gemini is now the first value (index 0), making it
/// the default when reading from SharedPreferences with no stored value.
///
/// The order matters — it determines the index stored in SharedPreferences
/// and thus the fallback default when no value is stored.
library;

/// Supported AI connection types.
///
/// The enum order is significant for SharedPreferences storage:
/// index 0 = default. Gemini is now the primary provider.
enum ConnectionType {
  /// Google Gemini native REST API (primary/default)
  gemini,

  /// OpenAI-compatible endpoint (e.g. api.openai.com)
  openaiCompatible,

  /// Custom OpenAI-compatible endpoint (user-specified URL)
  customOpenAI,
}
