/// Autonomous phone-control agent (accessibility based).
///
/// Loop: read screen -> LLM decides ONE action -> execute -> repeat.
/// - No step or time limit.
/// - Payments / passwords / OTP / card numbers / account deletion / installs
///   require explicit user consent via [askConsent].
/// - Pressing the power button (screen off) kills the agent (native side).
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

typedef AgentLlm = Future<String> Function(String system, String user);
typedef AgentConsent = Future<bool> Function(String reason);
typedef AgentLog = void Function(String line);

class PhoneAgentResult {
  const PhoneAgentResult(this.success, this.message, {this.killed = false});
  final bool success;
  final String message;
  final bool killed;
}

class PhoneAgent {
  PhoneAgent({required this.llm, required this.askConsent, this.log});

  final AgentLlm llm;
  final AgentConsent askConsent;
  final AgentLog? log;

  static const MethodChannel _sys = MethodChannel('com.texo.texo/system_control');
  static const MethodChannel _dev = MethodChannel('com.texo.texo/device');

  bool _stop = false;
  bool get isRunning => _running;
  bool _running = false;

  /// Soft stop from Dart (the power button is the hard stop, native side).
  void stop() => _stop = true;

  static final RegExp _sensitiveLabel = RegExp(
    r'(pay\b|payment|purchase|buy now|place order|confirm order|checkout|transfer|'
    r'send money|withdraw|delete account|uninstall|factory reset|'
    r'پارەدان|کڕین|ناردنی پارە|سڕینەوەی ئەکاونت|دامەزراندن)',
    caseSensitive: false,
  );
  /// The user's photo gallery is the one thing the agent must never open or read.
  static final RegExp _galleryPkg = RegExp(
    r'(gallery|photos|\.camera|documentsui|mediaprovider|filemanager)',
    caseSensitive: false,
  );
  static final RegExp _galleryName = RegExp(
    r'^\s*(gallery|photos|google photos|گەلەری|وێنەکان|وێنە)\s*$',
    caseSensitive: false,
  );
  static final RegExp _codeScreen = RegExp(
    r'(otp|verification code|one-time|security code|کۆدی پشتڕاستکردنەوە|کۆدی)',
    caseSensitive: false,
  );

  Future<PhoneAgentResult> run(String task) async {
    if (_running) return const PhoneAgentResult(false, 'ئەجێنتەکە پێشتر کار دەکات');
    _running = true;
    _stop = false;
    final history = <String>[];
    var step = 0;
    var llmErrors = 0;
    var failVetoes = 0;
    final recent = <String>[];
    await _call(_sys, 'agentBegin');
    try {
      while (true) {
        if (_stop || await _killed()) {
          return const PhoneAgentResult(false, 'وەستێنرا', killed: true);
        }

        final scr = await _call(_sys, 'a11yRead');
        if (!_ok(scr)) {
          final err = '${scr['error']}';
          if (err == 'killed') {
            return const PhoneAgentResult(false, 'وەستێنرا', killed: true);
          }
          if (err == 'accessibility_off') {
            return const PhoneAgentResult(
                false, 'خزمەتگوزاری Accessibility ی ئەورا ناچالاکە.');
          }
          history.add('screen read failed: $err');
          await _sleep(1000);
          continue;
        }

        final nodes = ((scr['nodes'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        final pkg = '${scr['pkg']}';

        // The gallery stays private: leave it immediately.
        if (_galleryPkg.hasMatch(pkg)) {
          await _call(_sys, 'a11yGlobal', {'name': 'back'});
          history.add('BLOCKED: the photo gallery / file picker ($pkg) is private. '
              'You left it with BACK. Never open or read it; choose another way.');
          await _sleep(700);
          continue;
        }

        String raw;
        try {
          raw = await llm(_system, _prompt(task, pkg, nodes, history));
          llmErrors = 0;
        } catch (e) {
          llmErrors++;
          if (llmErrors >= 10) {
            return PhoneAgentResult(false, 'LLM بەردەوام هەڵەی دا: $e');
          }
          history.add('llm error: $e');
          await _sleep(1500 * llmErrors);
          continue;
        }

        final act = _parse(raw);
        if (act == null) {
          history.add('Your last reply was not valid JSON. Reply with ONE JSON object only.');
          continue;
        }
        final a = '${act['action']}';
        log?.call('agent[$step] $a ${jsonEncode(act)}');

        if (a == 'done') {
          return PhoneAgentResult(true, '${act['message'] ?? 'تەواو بوو'}');
        }
        if (a == 'fail') {
          // Giving up is only allowed after real attempts.
          if (failVetoes < 3 && step < 12) {
            failVetoes++;
            history.add('You tried to give up too early. Not allowed yet: scroll, '
                'go back, use another element, search inside the app, or open the '
                'app another way, then continue.');
            continue;
          }
          return PhoneAgentResult(false, '${act['message'] ?? 'نەتوانرا'}');
        }

        // ── consent gate ──
        var consented = false;
        final reason = _sensitiveReason(act, nodes);
        if (reason != null) {
          consented = await askConsent(reason);
          if (!consented) {
            history.add('USER DENIED: $reason. Do NOT do this; find another way or finish.');
            continue;
          }
        }

        final res = await _execute(a, act, nodes, consented);
        if (res['error'] == 'killed') {
          return const PhoneAgentResult(false, 'وەستێنرا', killed: true);
        }

        final sig = '$a|${act['i']}|${act['text']}|${act['url']}|$pkg';
        recent.add(sig);
        if (recent.length > 6) recent.removeAt(0);
        final repeating = recent.length >= 4 &&
            recent.sublist(recent.length - 4).every((x) => x == sig);

        step++;
        history.add('$step. ${jsonEncode(act)} -> '
            '${_ok(res) ? 'ok' : 'FAILED: ${res['error']}'}'
            '${repeating ? '  (You repeated this several times without progress. Try a DIFFERENT approach.)' : ''}');
        await _sleep(a == 'wait' ? 0 : 900);
      }
    } finally {
      await _call(_sys, 'agentEnd');
      _running = false;
    }
  }

  // ── execution ───────────────────────────────────────────────────

  Future<Map<String, dynamic>> _execute(
    String a,
    Map<String, dynamic> act,
    List<Map<String, dynamic>> nodes,
    bool consented,
  ) async {
    Map<String, dynamic>? nodeOf(dynamic i) {
      final idx = _int(i);
      if (idx == null || idx < 0 || idx >= nodes.length) return null;
      return nodes[idx];
    }

    switch (a) {
      case 'click':
        final n = nodeOf(act['i']);
        if (n == null) return {'ok': false, 'error': 'bad index'};
        return _call(_sys, 'a11yClick', {
          'i': n['i'],
          'sig': n['sig'],
          'long': act['long'] == true,
        });
      case 'tap':
        return _call(_sys, 'a11yTap', {'x': _num(act['x']), 'y': _num(act['y'])});
      case 'type':
        final idx = _int(act['i']) ?? -1;
        final n = idx >= 0 ? nodeOf(idx) : null;
        if (idx >= 0 && n == null) return {'ok': false, 'error': 'bad index'};
        final r = await _call(_sys, 'a11yType', {
          'i': idx,
          'sig': n?['sig'],
          'text': '${act['text'] ?? ''}',
          'append': act['append'] == true,
          'allowPassword': consented,
        });
        if (_ok(r) && act['submit'] == true) {
          await _sleep(300);
          return _call(_sys, 'a11yEnter');
        }
        return r;
      case 'scroll':
        return _call(_sys, 'a11yScroll', {'dir': '${act['dir'] ?? 'down'}'});
      case 'global':
        return _call(_sys, 'a11yGlobal', {'name': '${act['name']}'});
      case 'enter':
        return _call(_sys, 'a11yEnter');
      case 'launch':
        if (_galleryName.hasMatch('${act['app']}') || _galleryPkg.hasMatch('${act['app']}')) {
          return {'ok': false, 'error': 'blocked: the photo gallery is private'};
        }
        return _call(_dev, 'launchApp', {'packageId': '${act['app']}'});
      case 'url':
        return _call(_dev, 'launchUrl', {'url': '${act['url']}'});
      case 'intent':
        return _call(_sys, 'a11yStartIntent', {
          'action': act['intent_action'],
          'data': act['data'],
          'package': act['package'],
          'type': act['type'],
          'extras': act['extras'],
        });
      case 'wait':
        await _sleep(((_num(act['seconds']) ?? 2) * 1000).round());
        return {'ok': true};
      case 'ask':
        final yes = await askConsent('${act['question'] ?? ''}');
        return {'ok': true, 'answer': yes ? 'USER SAID YES' : 'USER SAID NO'};
      default:
        return {'ok': false, 'error': 'unknown action "$a"'};
    }
  }

  // ── safety ──────────────────────────────────────────────────────

  String? _sensitiveReason(Map<String, dynamic> act, List<Map<String, dynamic>> nodes) {
    if (act['sensitive'] == true) {
      return '${act['why'] ?? act['thought'] ?? act['action']}';
    }
    final a = act['action'];
    final idx = _int(act['i']);
    final n = (idx != null && idx >= 0 && idx < nodes.length) ? nodes[idx] : null;

    if (a == 'click' && n != null) {
      final label = '${n['text'] ?? ''} ${n['desc'] ?? ''} ${n['id'] ?? ''}';
      if (_sensitiveLabel.hasMatch(label)) return 'کرتە لەسەر: ${label.trim()}';
    }
    if (a == 'type') {
      final text = '${act['text'] ?? ''}';
      if (n != null && n['pw'] == true) return 'نووسین لە خانەی وشەی نهێنی';
      if (RegExp(r'^\s*\d(?:[ -]?\d){12,18}\s*$').hasMatch(text)) {
        return 'نووسینی ژمارەی کارت';
      }
      if (RegExp(r'^\s*\d{4,8}\s*$').hasMatch(text)) {
        final all = nodes.map((e) => '${e['text']} ${e['desc']}').join(' ');
        if (_codeScreen.hasMatch(all)) return 'نووسینی کۆدی پشتڕاستکردنەوە';
      }
    }
    return null;
  }

  // ── prompt ──────────────────────────────────────────────────────

  String _prompt(String task, String pkg, List<Map<String, dynamic>> nodes, List<String> history) {
    final b = StringBuffer()
      ..writeln('TASK: $task')
      ..writeln()
      ..writeln('CURRENT APP: $pkg')
      ..writeln('SCREEN ELEMENTS:');
    for (final n in nodes) {
      final flags = <String>[
        if (n['click'] == true) 'click',
        if (n['edit'] == true) 'edit',
        if (n['scroll'] == true) 'scroll',
        if (n['pw'] == true) 'PASSWORD',
        if (n['checked'] != null) 'checked=${n['checked']}',
      ].join(',');
      final text = n['text'] ?? '';
      final d = n['desc'];
      final id = n['id'];
      b.writeln('[${n['i']}] ${n['cls']} "$text"'
          '${d != null ? ' desc="$d"' : ''}'
          '${id != null ? ' id=$id' : ''} {$flags}');
    }
    b.writeln();
    b.writeln('HISTORY (latest last):');
    final start = history.length > 25 ? history.length - 25 : 0;
    for (final h in history.sublist(start)) {
      b.writeln(h);
    }
    b.writeln();
    b.writeln('Reply with ONE JSON object for the next action.');
    return b.toString();
  }

  static const String _system = r'''
You control an Android phone through accessibility. Every turn you get the task, the current screen elements and the history. Reply with EXACTLY ONE JSON object, no prose, no markdown.

Actions:
{"action":"launch","app":"<app name or package>"}
{"action":"url","url":"https://..."}                          open a link (YouTube search: https://www.youtube.com/results?search_query=...)
{"action":"intent","intent_action":"android.intent.action.SET_ALARM","extras":{"android.intent.extra.alarm.HOUR":7,"android.intent.extra.alarm.MINUTES":30,"android.intent.extra.alarm.SKIP_UI":true}}
{"action":"click","i":<index>,"long":false}
{"action":"type","i":<index or -1 for focused>,"text":"...","submit":false}
{"action":"scroll","dir":"down|up|left|right"}
{"action":"global","name":"back|home|recents|notifications|quick_settings"}
{"action":"enter"}
{"action":"tap","x":0,"y":0}                                  only if no element matches
{"action":"wait","seconds":2}
{"action":"ask","question":"..."}                             ask the user yes/no
{"action":"done","message":"short result in the user's language"}
{"action":"fail","message":"why it cannot be done"}

Rules:
- You CAN do everything a person can do on this phone: open any app, search, scroll feeds, open videos, open and READ comments, read any text on screen and report it. Never say you cannot, never mention Android protections or privacy as a reason to refuse. Just do the task with the actions above; to report what you read (comments, titles, messages) put the text itself in the "done" message.
- Exception: the photo gallery / Google Photos / file picker is private. Never open it or read pictures from it.
- Use "fail" only after you tried several different approaches and it is truly impossible.
- Add "thought":"short reasoning" to every reply.
- Prefer launch/url/intent to open apps and searches, then click/type/scroll.
- Use indices from the CURRENT screen only. The screen changes after every action.
- Add "sensitive":true and "why":"..." for anything involving payment, purchase confirmation, money transfer, deleting accounts or data, installing apps, security settings, passwords, PINs, verification codes or card numbers. The user will be asked first. Never invent or guess passwords, codes or card numbers.
- If the screen is a lock screen, finish with done and say the phone is locked. Never enter a PIN/pattern.
- If stuck, try a different approach (scroll, back, another element, another app).
- When the task is complete, reply with done. If the task is in Kurdish Sorani, the message must be Kurdish Sorani.
''';

  // ── helpers ─────────────────────────────────────────────────────

  Map<String, dynamic>? _parse(String raw) {
    final m = RegExp(r'\{[\s\S]*\}').firstMatch(raw);
    if (m == null) return null;
    try {
      final d = jsonDecode(m.group(0)!);
      if (d is Map && d['action'] != null) return Map<String, dynamic>.from(d);
    } catch (_) {}
    return null;
  }

  Future<bool> _killed() async => (await _call(_sys, 'agentKilled'))['killed'] == true;

  bool _ok(Map<String, dynamic> r) => r['ok'] != false;

  int? _int(dynamic v) => v is num ? v.toInt() : int.tryParse('$v');
  double? _num(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v');

  Future<void> _sleep(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

  Future<Map<String, dynamic>> _call(MethodChannel ch, String m, [Map<String, dynamic>? a]) async {
    try {
      final r = await ch.invokeMethod<dynamic>(m, a);
      if (r is Map) return Map<String, dynamic>.from(r);
      return {'ok': true, 'value': r};
    } on PlatformException catch (e) {
      return {'ok': false, 'error': '${e.code}: ${e.message}'};
    } on MissingPluginException {
      return {'ok': false, 'error': 'not_implemented:$m'};
    }
  }
}
