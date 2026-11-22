import 'dart:typed_data';

import 'package:flutter/services.dart';

/// Plays raw PCM (16-bit, mono, 24 kHz) through a native AudioTrack.
/// Gemini Live sends its spoken replies in exactly this format.
class PcmPlayer {
  static const MethodChannel _ch = MethodChannel('com.texo.texo/system_control');

  /// Queues one chunk of PCM bytes for playback.
  Future<void> write(Uint8List pcm) async {
    await _ch.invokeMethod<dynamic>('pcmWrite', {'data': pcm});
  }

  /// Stops playback and releases the audio track.
  Future<void> stop() async {
    await _ch.invokeMethod<dynamic>('pcmStop');
  }
}
