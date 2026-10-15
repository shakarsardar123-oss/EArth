import 'dart:async';
import 'dart:convert';
import 'dart:io' show File;
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/agent/agent_context.dart';
import '../core/ai/ai_message.dart';
import '../core/live_mode/live_mode_providers.dart';
import '../core/live_mode/live_mode_state.dart';
import '../core/localization/locale_provider.dart';
import '../domain/services/ai_service.dart';
import '../presentation/providers/app_providers.dart';
import '../ui/texo_ui.dart';
import 'live_camera.dart';

/// Connects the new UI ([TexoBackend]) to the existing app logic (Riverpod).
class RiverpodBackend implements TexoBackend {
  RiverpodBackend(this._c);

  final ProviderContainer _c;
  final LiveVoiceSource _live = LiveVoiceSource();
  final LiveCamera _cam = LiveCamera();

  String? _convId;
  Timer? _levelTimer;
  ProviderSubscription<LiveModeState>? _liveSub;
  final Stopwatch _sw = Stopwatch();

  // ---- language -------------------------------------------------------------

  String get initialLang => _c.read(overriddenLocaleProvider).code;

  void setLang(String lang) {
    _c
        .read(overriddenLocaleProvider.notifier)
        .setLocale(lang == 'en' ? AuraLocale.en : AuraLocale.ku);
  }

  // ---- identity ---------------------------------------------------------------

  @override
  String get userName {
    final String? saved = _c.read(sharedPreferencesProvider).getString('user_name');
    return (saved != null && saved.trim().isNotEmpty) ? saved.trim() : 'شاکار';
  }

  // ---- chat ---------------------------------------------------------------------

  @override
  void beginChat(String? conversationId) {
    _convId = conversationId;
  }

  static String _short(String s, int n) {
    final String t = s.replaceAll('\n', ' ').trim();
    return t.length > n ? '${t.substring(0, n)}…' : t;
  }

  static String _mimeFor(String name, String? ext) {
    final String e = (ext ?? name.split('.').last).toLowerCase();
    const Map<String, String> m = <String, String>{
      'wav': 'audio/wav',
      'mp3': 'audio/mp3',
      'm4a': 'audio/mp4',
      'aac': 'audio/aac',
      'ogg': 'audio/ogg',
      'oga': 'audio/ogg',
      'opus': 'audio/ogg',
      'flac': 'audio/flac',
      'png': 'image/png',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'webp': 'image/webp',
      'heic': 'image/heic',
      'pdf': 'application/pdf',
      'txt': 'text/plain',
      'md': 'text/plain',
      'mp4': 'video/mp4',
      'mov': 'video/quicktime',
      '3gp': 'video/3gpp',
    };
    return m[e] ?? 'application/octet-stream';
  }

  @override
  Future<UiAttachment?> pickAttachment() async {
    final FilePickerResult? r = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      withData: true,
    );
    if (r == null || r.files.isEmpty) return null;
    final PlatformFile f = r.files.first;
    var bytes = f.bytes;
    if (bytes == null && f.path != null) {
      bytes = await File(f.path!).readAsBytes();
    }
    if (bytes == null) return null;
    return UiAttachment(name: f.name, mime: _mimeFor(f.name, f.extension), bytes: bytes);
  }

  @override
  Future<String> ask(
    String text, {
    String? conversationId,
    List<UiAttachment> attachments = const <UiAttachment>[],
  }) async {
    final memory = _c.read(memoryServiceProvider);
    String? convId = _convId ?? conversationId;
    try {
      convId ??= await memory.createConversation(title: _short(text, 40), agentId: 'default');
      _convId = convId;
    } catch (_) {}

    final List<Map<String, String>> history = <Map<String, String>>[];
    final List<AIMessage> historyMsgs = <AIMessage>[];
    if (convId != null) {
      try {
        for (final m in await memory.getMessages(convId)) {
          final bool user = m.role == 'user';
          history.add(<String, String>{'role': user ? 'user' : 'assistant', 'content': m.content});
          historyMsgs.add(AIMessage(
            role: user ? AIMessageRole.user : AIMessageRole.assistant,
            content: m.content,
          ));
        }
      } catch (_) {}
    }

    String reply;
    bool ok = true;
    try {
      if (attachments.isNotEmpty) {
        int total = 0;
        for (final UiAttachment a in attachments) {
          total += a.bytes.length;
        }
        if (total > 15 * 1024 * 1024) {
          return 'فایلەکە زۆر گەورەیە. سنووری ١٥ مێگابایتە.';
        }
        final provider = _c.read(selectedAIProviderProvider);
        final msg = AIMessage(
          role: AIMessageRole.user,
          content: text,
          metadata: <String, dynamic>{
            'attachments': <Map<String, String>>[
              for (final UiAttachment a in attachments)
                <String, String>{'mime': a.mime, 'name': a.name, 'data': base64Encode(a.bytes)},
            ],
          },
        );
        final res = await provider.complete(AIRequest(
          prompt: text,
          agentConfig: _c.read(agentConfigProvider),
          messages: <AIMessage>[...historyMsgs, msg],
        ));
        reply = res.text;
      } else {
        final result = await _c.read(agentEngineProvider).run(
              userInput: text,
              context: AgentContext(
                agentConfig: _c.read(agentConfigProvider),
                conversationHistory: history,
                maxSteps: 10,
              ),
            );
        ok = result.isSuccess && result.response != null;
        reply = ok
            ? result.response!
            : (result.errorMessage ?? 'ببورە، نەمتوانم وەڵام بدەمەوە.');
      }
    } catch (e) {
      ok = false;
      reply = 'ببورە، هەڵەیەک ڕوویدا: $e';
    }

    if (ok && convId != null) {
      try {
        await memory.addMessage(conversationId: convId, role: 'user', content: text);
        await memory.addMessage(conversationId: convId, role: 'assistant', content: reply);
      } catch (_) {}
    }
    return reply;
  }

  @override
  Future<void> speak(String text) async {
    // TODO: connect to the TTS service (VoiceServiceImpl.speak).
  }

  @override
  Future<List<UiConversation>> conversations() async {
    final memory = _c.read(memoryServiceProvider);
    final List<String> ids = await memory.getConversationIds(limit: 40);
    final List<UiConversation> out = <UiConversation>[];
    for (final String id in ids) {
      final msgs = await memory.getMessages(id);
      if (msgs.isEmpty) continue;
      final first = msgs.firstWhere((m) => m.role == 'user', orElse: () => msgs.first);
      final last = msgs.last;
      out.add(UiConversation(
        id: id,
        title: _short(first.content, 46),
        snippet: _short(last.content, 60),
        time: last.createdAt ?? first.createdAt ?? DateTime.now(),
      ));
    }
    return out;
  }

  @override
  Future<List<UiMessage>> messages(String conversationId) async {
    final msgs = await _c.read(memoryServiceProvider).getMessages(conversationId);
    return <UiMessage>[
      for (final m in msgs) UiMessage(isUser: m.role == 'user', text: m.content),
    ];
  }

  // ---- settings -----------------------------------------------------------------

  static const Map<String, bool> _toggleDefaults = <String, bool>{
    'wake': true,
    'read': true,
    'hap': false,
  };

  @override
  Future<Map<String, bool>> toggles() async {
    final prefs = _c.read(sharedPreferencesProvider);
    return <String, bool>{
      for (final MapEntry<String, bool> e in _toggleDefaults.entries)
        e.key: prefs.getBool('ui.toggle.${e.key}') ?? e.value,
    };
  }

  @override
  Future<void> setToggle(String key, bool value) async {
    await _c.read(sharedPreferencesProvider).setBool('ui.toggle.$key', value);
  }

  @override
  Future<Map<String, bool>> permissionStates() async {
    bool overlay = false;
    try {
      overlay = await Permission.systemAlertWindow.isGranted;
    } catch (_) {}
    // TODO: real accessibility-service status.
    return <String, bool>{'overlay': overlay, 'access': false};
  }

  @override
  Future<void> openPermission(String key) async {
    if (key == 'overlay') {
      await Permission.systemAlertWindow.request();
    } else {
      // TODO: open the Accessibility settings screen.
      await openAppSettings();
    }
  }

  @override
  Future<bool> hasApiKey() async {
    final String? k = await _c.read(geminiProviderProvider).getApiKey();
    return k != null && k.trim().isNotEmpty;
  }

  @override
  Future<void> setApiKey(String key) async {
    await _c.read(geminiProviderProvider).setApiKey(key.trim());
  }

  // ---- live ---------------------------------------------------------------------

  @override
  LiveVoiceSource get liveSource => _live;

  void _applyState(LiveModeState s) {
    _live.mode.value = s == LiveModeState.processing
        ? LiveMode.thinking
        : (s == LiveModeState.speaking ? LiveMode.speaking : LiveMode.listening);
    _cam.capturing = _live.mode.value == LiveMode.listening;
  }

  @override
  Future<void> startLive() async {
    final PermissionStatus st = await Permission.microphone.request();
    if (!st.isGranted) return;
    _liveSub?.close();
    _liveSub = _c.listen<LiveModeState>(
      liveModeStateProvider,
      (LiveModeState? prev, LiveModeState next) => _applyState(next),
      fireImmediately: true,
    );
    _sw
      ..reset()
      ..start();
    _levelTimer?.cancel();
    _levelTimer = Timer.periodic(const Duration(milliseconds: 16), (Timer _) => _tickLevel());
    await _c.read(liveModeOrchestratorProvider).startSession();
  }

  /// Until real microphone / TTS levels are connected, the level is a gentle
  /// speech-like envelope that depends on the live-mode state.
  void _tickLevel() {
    final double t = _sw.elapsedMilliseconds / 1000.0;
    final LiveMode m = _live.mode.value;
    final double phr = math.pow(math.max(0.0, math.sin(t * 0.85)), 0.7).toDouble();
    final double syl = 0.5 + 0.5 * math.sin(t * 6.3 + math.sin(t * 1.7) * 2);
    double v;
    if (m == LiveMode.speaking) {
      v = 0.12 + 0.75 * phr * (0.40 + 0.60 * syl);
    } else if (m == LiveMode.thinking) {
      v = 0.10 + 0.04 * math.sin(t * 2);
    } else {
      v = 0.08 + 0.05 * math.sin(t * 1.3);
    }
    _live.level.value = v;
  }

  @override
  Future<void> stopLive() async {
    _levelTimer?.cancel();
    _levelTimer = null;
    _liveSub?.close();
    _liveSub = null;
    _live.level.value = 0;
    await _cam.stop();
    try {
      await _c.read(liveModeOrchestratorProvider).stopSession();
    } catch (_) {}
  }

  @override
  ValueListenable<bool> get cameraActive => _cam.active;

  @override
  Future<void> setCamera(bool on) => on ? _cam.start() : _cam.stop();

  @override
  Future<void> switchCamera() => _cam.switchCamera();

  @override
  Widget? buildCameraPreview() => _cam.preview();

  @override
  Future<void> toggleMic() async {
    // TODO: mute / unmute the microphone.
  }
}
