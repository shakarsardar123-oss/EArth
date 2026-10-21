import 'dart:async';
import 'dart:convert';
import 'dart:io' show File;
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Icons, Theme;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/agent/agent_context.dart';
import '../core/ai/ai_message.dart';
import '../core/live_mode/live_mode_providers.dart';
import '../core/live_mode/live_mode_state.dart';
import '../core/localization/locale_provider.dart';
import '../core/theme/app_theme.dart';
import '../core/voice/voice_service_provider.dart';
import '../domain/services/ai_service.dart';
import '../presentation/providers/app_providers.dart';
import '../presentation/screens/vision_screen.dart';
import '../ui/texo_ui.dart';
import '../ui/src/backend.dart' show TexoCameraExtras;
import 'live_camera.dart';
import 'overlay_controller.dart';

/// Connects the new UI ([TexoBackend]) to the existing app logic (Riverpod).
class RiverpodBackend implements TexoBackend, TexoCameraExtras {
  RiverpodBackend(this._c);

  final ProviderContainer _c;
  final LiveVoiceSource _live = LiveVoiceSource();
  final LiveCamera _cam = LiveCamera();
  late final OverlayController _overlay = OverlayController(onAction: _onOverlayAction);
  int _ovTick = 0;
  bool _micOff = false;
  bool _muted = false;
  bool _subs = false;
  String _lastYou = '';
  String _lastAi = '';
  StreamSubscription<double>? _ttsSub;
  double _ttsLevel = 0;
  int _ttsAt = 0;
  bool _muteStopped = false;
  bool _liveRunning = false;
  Future<void> _tail = Future<void>.value();
  String _lastPushKey = '';
  int _lastPushAt = 0;

  /// Start / stop of Live Mode run one after another, so quick taps can never
  /// start and stop it at the same time.
  Future<void> _serial(Future<void> Function() job) {
    final Future<void> next = _tail.then((_) => job()).catchError((Object _) {});
    _tail = next;
    return next;
  }

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
  List<UiExtraEntry> get extraEntries => <UiExtraEntry>[
        UiExtraEntry(
          titleKu: 'بینین',
          titleEn: 'Vision',
          icon: Icons.visibility_outlined,
          builder: (BuildContext context) =>
              Theme(data: AppTheme.dark(), child: VisionScreen()),
        ),
      ];

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
    await _c.read(voiceServiceImplProvider).speak(text);
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
    if (_muted && _live.mode.value == LiveMode.speaking && !_muteStopped) {
      _muteStopped = true;
      _c.read(voiceServiceImplProvider).stopSpeaking();
    }
    if (_live.mode.value != LiveMode.speaking) _muteStopped = false;
    _pushOverlay();
  }

  @override
  Future<void> startLive() => _serial(_startLive);

  Future<void> _startLive() async {
    if (_liveRunning) return;
    final PermissionStatus st = await Permission.microphone.request();
    if (!st.isGranted) return;
    _liveRunning = true;
    _micOff = false;
    _muted = false;
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
    _live.active.value = true;
    _lastYou = '';
    _lastAi = '';
    _live.caption.value = '';
    _ttsSub?.cancel();
    _ttsSub = _c.read(voiceServiceImplProvider).speakingLevelStream.listen((double v) {
      _ttsLevel = v.clamp(0.0, 1.0).toDouble();
      _ttsAt = DateTime.now().millisecondsSinceEpoch;
    });
    await _overlay.start();
    _pushFlags();
    final orchestrator = _c.read(liveModeOrchestratorProvider);
    orchestrator.onUserRecognized = (String text) {
      _lastYou = text;
      _live.caption.value = text;
      _pushOverlay();
    };
    orchestrator.onAIResponse = (String text) {
      final String clean = text.split('```').first.trim();
      _lastAi = clean;
      _live.caption.value = clean;
      _pushOverlay();
    };
    orchestrator.onSessionEnded = (String reason) {
      _live.active.value = false;
    };
    await orchestrator.startSession();
    // The old live-mode code may have registered its own overlay handler or
    // shown the pill while the app is visible: take both back.
    _overlay.rebind();
    await _overlay.syncVisibility();
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
      final bool real = DateTime.now().millisecondsSinceEpoch - _ttsAt < 300;
      v = real ? 0.10 + 0.85 * _ttsLevel : 0.12 + 0.75 * phr * (0.40 + 0.60 * syl);
    } else if (m == LiveMode.thinking) {
      v = 0.10 + 0.04 * math.sin(t * 2);
    } else {
      v = 0.08 + 0.05 * math.sin(t * 1.3);
    }
    _live.level.value = v;
    if (++_ovTick % 5 == 0) _pushOverlay();
  }

  @override
  Future<void> stopLive() => _serial(_stopLive);

  Future<void> _stopLive() async {
    _liveRunning = false;
    _levelTimer?.cancel();
    _levelTimer = null;
    _liveSub?.close();
    _liveSub = null;
    _live.level.value = 0;
    await _cam.stop();
    await _overlay.stop();
    await _ttsSub?.cancel();
    _ttsSub = null;
    try {
      await _c.read(liveModeOrchestratorProvider).stopSession();
    } catch (_) {}
  }

  String _emoji(LiveMode m) {
    if (m == LiveMode.thinking) return '\u{1F914}';
    if (m == LiveMode.speaking) {
      const List<String> e = <String>['\u{1F604}', '\u{1F62E}', '\u{1F3B5}', '\u{1F970}'];
      return e[(DateTime.now().millisecondsSinceEpoch ~/ 2200) % e.length];
    }
    return '\u{1F642}';
  }

  void _pushOverlay() {
    final LiveMode m = _live.mode.value;
    final double level = (_live.level.value * 20).round() / 20.0;
    final String emoji = _emoji(m);
    final int now = DateTime.now().millisecondsSinceEpoch;
    final String key = '$m|$level|$emoji|$initialLang|$_lastYou|$_lastAi';
    // Only talk to the native overlay when something changed (plus a
    // keep-alive once a second): far fewer platform-channel calls.
    if (key == _lastPushKey && now - _lastPushAt < 1000) return;
    _lastPushKey = key;
    _lastPushAt = now;
    _overlay.push(<String, Object?>{
      'mode': m == LiveMode.thinking ? 'thinking' : (m == LiveMode.speaking ? 'speaking' : 'listening'),
      'level': level,
      'emoji': emoji,
      'lang': initialLang,
      'you': _lastYou,
      'ai': _lastAi,
    });
  }

  /// The toggles (mic, mute, subtitles) are only sent when they change: the
  /// native overlay owns them while the user taps its buttons.
  void _pushFlags() {
    _overlay.push(<String, Object?>{
      'micOff': _micOff,
      'muted': _muted,
      'subs': _subs,
    });
  }

  void _onOverlayAction(String action) {
    final int eq = action.indexOf('=');
    final String name = eq >= 0 ? action.substring(0, eq) : action;
    final bool? value = eq >= 0 ? action.substring(eq + 1) == '1' : null;
    switch (name) {
      case 'close':
        _live.active.value = false;
        stopLive();
        break;
      case 'mic':
        _micOff = value ?? !_micOff; // TODO: really mute the microphone
        _pushFlags();
        break;
      case 'mute':
        _muted = value ?? !_muted; // best effort: speech is stopped whenever the assistant starts talking
        if (_muted) _c.read(voiceServiceImplProvider).stopSpeaking();
        _pushFlags();
        break;
      case 'subs':
        _subs = value ?? !_subs;
        _pushFlags();
        break;
      default:
        break; // translate / guide / tray_open / tray_close / hide / show: later
    }
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
  ValueListenable<bool> get torchOn => _cam.torchOn;

  @override
  ValueListenable<bool> get cameraIsFront => _cam.isFront;

  @override
  Future<void> toggleTorch() => _cam.toggleTorch();

  @override
  Future<void> toggleMic() async {
    // TODO: mute / unmute the microphone.
  }
}
