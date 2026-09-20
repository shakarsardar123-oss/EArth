/// Utility for masking API keys in UI display.
///
/// Never reveals more than the last 4 characters of a key.
class ApiKeyMasker {
  const ApiKeyMasker._();

  /// Masks [key] for safe display.
  ///
  /// - Keys with length ≤ 4: returns bullet characters of the same length.
  /// - Keys with length > 4: returns 8 bullet characters + the last 4 chars.
  /// - Empty string: returns empty string.
  static String mask(String key) {
    if (key.isEmpty) return '';
    if (key.length <= 4) return '•' * key.length;
    return '${'•' * 8}${key.substring(key.length - 4)}';
  }
}
