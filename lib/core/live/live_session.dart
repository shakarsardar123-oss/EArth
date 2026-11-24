import 'mic_capture.dart';
import 'dart:typed_data';
import 'dart:async';

import 'gemini_live_client.dart';
import 'pcm_player.dart';

/// One voice session: Gemini Live audio in/out, played natively.
/// Barge-in: when the user talks over the model, playback stops at once.
class LiveVoiceSession {
  LiveVoiceSession({required String apiKey}) : _client = GeminiLiveClient(apiKey: apiKey);

  final GeminiLiveClient _client;
  late final MicCapture _mic = MicCapture(_client);
  final PcmPlayer _player = PcmPlayer();
  StreamSubscription<Uint8List>? _audioSub;
  StreamSubscription<void>? _intSub;

  Future<bool> start() async {
    await _client.connect();
    _audioSub = _client.audioChunks.listen((chunk) => _player.write(chunk));
    _intSub = _client.interrupted.listen((_) => _player.stop());
    return true;
    final micOk = await _mic.start();
    if (!micOk) {
      await stop();
      throw StateError('mic not available');
    }
  }

  /// Sends one text turn; the answer arrives as audio.
  void ask(String text) => _client.sendText(text);

  Future<void> stop() async {
    await _audioSub?.cancel();
    await _intSub?.cancel();
    await _mic.stop();
    await _client.close();
    await _player.stop();
  }
}
