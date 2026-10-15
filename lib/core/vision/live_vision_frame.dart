import 'dart:typed_data';

/// Holds the latest camera frame while Live Mode's camera is on. The Gemini
/// provider attaches it to the user's current message so the assistant can see.
class LiveVisionFrame {
  LiveVisionFrame._();

  static bool enabled = false;
  static Uint8List? _bytes;
  static DateTime? _at;

  static void set(Uint8List bytes) {
    _bytes = bytes;
    _at = DateTime.now();
  }

  static void clear() {
    _bytes = null;
    _at = null;
    enabled = false;
  }

  /// The latest frame if the camera is on and the frame is recent enough.
  static Uint8List? fresh({Duration maxAge = const Duration(seconds: 15)}) {
    if (!enabled) return null;
    final Uint8List? b = _bytes;
    final DateTime? t = _at;
    if (b == null || t == null) return null;
    if (DateTime.now().difference(t) > maxAge) return null;
    return b;
  }
}
