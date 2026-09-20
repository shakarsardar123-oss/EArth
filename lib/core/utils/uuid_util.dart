/// Simple UUID v4 generator.
/// Replaces package:uuid to avoid pub get timeout issues in sandbox.
/// Generates RFC 4122 version 4 UUIDs using dart:math Random.
import 'dart:math';

class UuidUtil {
  UuidUtil();

  static final Random _random = Random();

  /// Generate a UUID v4 string (e.g. '550e8400-e29b-41d4-a716-446655440000').
  String v4() {
    // 16 random bytes as hex
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));

    // Set version to 4 (bits 12-15 of byte 6)
    bytes[6] = (bytes[6] & 0x0F) | 0x40;

    // Set variant to RFC 4122 (bits 6-7 of byte 8)
    bytes[8] = (bytes[8] & 0x3F) | 0x80;

    // Format as 8-4-4-4-12 hex string
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20, 32)}';
  }
}
