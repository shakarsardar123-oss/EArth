import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'gemini_live_client.dart';

/// Captures the microphone natively and streams 16 kHz PCM into Live.
class MicCapture {
  MicCapture(this._client) {
    _ch.setMethodCallHandler(_onCall);
  }

  static const MethodChannel _ctl = MethodChannel('com.texo.texo/system_control');
  static const MethodChannel _ch = MethodChannel('com.texo.texo/mic_out');
  final GeminiLiveClient _client;
  bool _on = false;

  bool get isOn => _on;

  Future<bool> start() async {
    final r = await _ctl.invokeMethod<Map<dynamic, dynamic>>('micStart');
    _on = r?['ok'] == true;
    return _on;
  }

  Future<void> stop() async {
    await _ctl.invokeMethod<dynamic>('micStop');
    _on = false;
    _client.endAudioStream();
  }

  Future<dynamic> _onCall(MethodCall call) async {
    if (call.method == 'micChunk' && _on) {
      final data = call.arguments as Uint8List;
      _client.sendAudio(data);
    }
    return null;
  }
}
