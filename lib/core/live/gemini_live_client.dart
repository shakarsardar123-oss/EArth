import 'live_prompt.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Gemini Live (BidiGenerateContent) over WebSocket.
/// Text in, audio out. No microphone here yet.
class GeminiLiveClient {
  GeminiLiveClient({
    required this.apiKey,
    this.model = 'models/gemini-2.5-flash-native-audio-preview-12-2025',
    this.systemInstruction = kLiveSystemPrompt,
  });

  final String apiKey;
  final String model;
  final String systemInstruction;

  WebSocket? _ws;
  StreamSubscription<dynamic>? _sub;
  Completer<void>? _setup;
  bool _closed = false;

  final StreamController<Uint8List> _audio =
      StreamController<Uint8List>.broadcast();
  final StreamController<void> _turnDone =
      StreamController<void>.broadcast();
  final StreamController<String> _heard =
      StreamController<String>.broadcast();
  final StreamController<void> _interruptedCtrl =
      StreamController<void>.broadcast();

  /// Fires when the user starts speaking over the model (barge-in).
  Stream<void> get interrupted => _interruptedCtrl.stream;

  /// PCM 16-bit mono, 24 kHz chunks of the model's spoken reply.
  Stream<Uint8List> get audioChunks => _audio.stream;

  /// Fires once when the model finishes its turn.
  Stream<void> get turnComplete => _turnDone.stream;

  /// What the model heard (input transcription), when available.
  Stream<String> get heard => _heard.stream;

  bool get isConnected => _ws != null && !_closed;

  Future<void> connect() async {
    if (isConnected) return;
    _closed = false;
    final url =
        'wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent?key=$apiKey';
    final ws = await WebSocket.connect(url).timeout(const Duration(seconds: 20));
    _ws = ws;
    _setup = Completer<void>();
    _sub = ws.listen(
      _onMessage,
      onError: (Object e) {
        final c = _setup;
        if (c != null && !c.isCompleted) c.completeError(e);
        _ws = null;
      },
      onDone: () {
        _ws = null;
      },
    );

    ws.add(jsonEncode({
      'setup': {
        'model': model,
        'generationConfig': {
          'responseModalities': ['AUDIO'],
        },
        if (systemInstruction.isNotEmpty)
          'systemInstruction': {
            'parts': [
              {'text': systemInstruction},
            ],
          },
        'inputAudioTranscription': {},
      },
    }));

    await _setup!.future.timeout(const Duration(seconds: 20));
  }

  /// Sends one chunk of microphone audio: PCM 16-bit mono, 16 kHz.
  void sendAudio(Uint8List pcm16k) {
    final ws = _ws;
    if (ws == null) return;
    ws.add(jsonEncode({
      'realtimeInput': {
        'mediaChunks': [
          {'mimeType': 'audio/pcm;rate=16000', 'data': base64Encode(pcm16k)},
        ],
      },
    }));
  }

  /// Tells the model the user has stopped speaking (end of a turn).
  void endAudioStream() {
    final ws = _ws;
    if (ws == null) return;
    ws.add(jsonEncode({'realtimeInput': {'audioStreamEnd': true}}));
  }

  /// Sends one camera frame (JPEG) into the live conversation.
  void sendImage(Uint8List jpeg) {
    final ws = _ws;
    if (ws == null) return;
    ws.add(jsonEncode({
      'realtimeInput': {
        'mediaChunks': [
          {'mimeType': 'image/jpeg', 'data': base64Encode(jpeg)},
        ],
      },
    }));
  }

  /// Sends one user text turn. The model answers with audio on [audioChunks].
  void sendText(String text) {
    final ws = _ws;
    if (ws == null) throw StateError('Live client is not connected');
    ws.add(jsonEncode({
      'clientContent': {
        'turns': [
          {
            'role': 'user',
            'parts': [
              {'text': text},
            ],
          },
        ],
        'turnComplete': true,
      },
    }));
  }

  void _onMessage(dynamic raw) {
    final String text =
        raw is String ? raw : utf8.decode(raw as List<int>);
    final Map<String, dynamic> d = jsonDecode(text) as Map<String, dynamic>;

    if (d.containsKey('setupComplete')) {
      final c = _setup;
      if (c != null && !c.isCompleted) c.complete();
      return;
    }

    final sc = d['serverContent'] as Map<String, dynamic>?;
    if (sc == null) return;
    if (sc['interrupted'] == true) _interruptedCtrl.add(null);

    final inT = sc['inputTranscription'] as Map<String, dynamic>?;
    final heardText = inT?['text'] as String?;
    if (heardText != null && heardText.isNotEmpty) _heard.add(heardText);

    final modelTurn = sc['modelTurn'] as Map<String, dynamic>?;
    final parts = (modelTurn?['parts'] as List<dynamic>?) ?? const [];
    for (final p in parts) {
      final inl = (p as Map<String, dynamic>)['inlineData'] as Map<String, dynamic>?;
      final data = inl?['data'] as String?;
      if (data != null && data.isNotEmpty) {
        _audio.add(Uint8List.fromList(base64Decode(data)));
      }
    }

    if (sc['turnComplete'] == true) _turnDone.add(null);
  }

  Future<void> close() async {
    _closed = true;
    await _sub?.cancel();
    await _ws?.close();
    _ws = null;
  }
}
