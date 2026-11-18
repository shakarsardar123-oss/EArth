/// Phone-control entry point.
///
/// [tryHandle] is installed as [phoneControlHook] and is called from
/// AgentEngine.run() for every screen. [run] only delegates to [inner]
/// (the hook already ran inside it), so nothing is classified twice.
library;

import '../../ui/src/theme_bus.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../../domain/entities/agent_config.dart';
import '../../domain/services/ai_service.dart';
import '../../services/ai/ai_provider.dart';
import '../ai/ai_message.dart';
import '../agent/agent_context.dart';
import '../agent/agent_result.dart';
import '../live_mode/agent_processor.dart';
import 'phone_agent.dart';

class PhoneControlProcessor implements AgentProcessor {
  PhoneControlProcessor({
    required this.providerGetter,
    this.inner,
  });

  final AIProvider Function() providerGetter;
  final AgentProcessor? inner;

  String _modelId = 'default';

  static const MethodChannel _sys =
      MethodChannel('com.texo.texo/system_control');
  static const MethodChannel _ovColor =
      MethodChannel('com.texo.texo/floating_texo_overlay');

  late final PhoneAgent _agent = PhoneAgent(
    llm: _llm,
    askConsent: _consent,
    log: (l) => _toast(l),
  );

  // Cheap pre-filter so ordinary chat never pays for a classifier call.
  static final RegExp _hint = RegExp(
    r'(ئۆڤەر|ڕەنگ|overlay|color|تێم|تاریک|دارک|theme|dark mode|light mode|بکەرەوە|بکەوە|بکەنەوە|هەڵکە|هەڵبکە|دابنێ|دایبنێ|بدۆزەوە|بگەڕێ|بچۆ|بنێرە|بنووسە|'
    r'دایبگرە|بگۆڕە|بکوژێنەوە|ئەلارم|ئەلەرم|ئەپ|یوتوب|فەیسبووک|ئینستاگرام|تیکتۆک|'
    r'واتسئەپ|تێلێگرام|سناپ|گۆرانی|وای ?فای|بلوتوس|open|launch|play|search|go to|'
    r'alarm|turn on|turn off|send|call|youtube|facebook|instagram|whatsapp|'
    r'پەخش|لێبدە|ڤیدیۆ|مەسێنجەر|ڤایبەر|سپۆتیفای|گووگڵ|کرۆم|نەخشە|ڕێکخستن|'
    r'spotify|chrome|maps|settings|message|telegram|snapchat|tiktok|'
    r'website|browser|google|wifi|bluetooth|volume|brightness|flashlight|camera|'
    r'contacts|call|sms|gmail|twitter|http|www|'
    r'کۆمێنت|مالپەڕ|وێبسایت|گووگڵ|براوزەر|ڕووناکی|دەنگ|فلاش|کامێرا|پەیام|'
    r'پەیوەندی|تەلەفۆن|جیمەیل|ئێکس|تویتەر|ئینتەرنێت)',
    caseSensitive: false,
  );

  @override
  Future<AgentResult> run({
    required String userInput,
    required AgentContext context,
  }) async {
    final i = inner;
    if (i == null) {
      return const AgentResult.failure(errorMessage: 'no inner processor');
    }
    return i.run(userInput: userInput, context: context);
  }

  Future<AgentResult?> tryHandle(String userInput, AgentContext context) async {
    if (RegExp(r'وەستێنە|ڕاگرە|وەستە|stop|cancel').hasMatch(userInput.toLowerCase())) {
      _cancelRequested = true;
      try { _agent.stop(); } catch (_) {}
      return const AgentResult.success(response: 'وەستێنرا.');
    }
    _cancelRequested = false;
    if (!_hint.hasMatch(userInput)) return null;
    _modelId = context.agentConfig.modelId;

    if (_agent.isRunning) {
      return const AgentResult.success(
        response: 'هێشتا خەریکی کارەکەی پێشووم.',
      );
    }
    if (!_isPhoneTaskLocal(userInput)) return null;

    final fast = await _tryFast(userInput);
    if (fast != null) return AgentResult.success(response: fast);

    _toast('TEXO: agent starting');
    final r = await _agent.run(userInput);
    _toast('TEXO: agent finished: ${r.message}');
    return AgentResult.success(response: r.killed ? 'وەستێنرا.' : r.message);
  }

  static final RegExp _questionLike = RegExp(
    r'(^|\s)(چی|چیە|چییە|چین|چۆن|چۆنە|بۆچی|کێ|کێیە|کەی|کەیە|لەکوێ|لەکوێیە|کامە|کامەیە|کام|چەند|چەندە|ئایا|what|how|why|who|when|where)(\s|$)|[؟?]\s*$',
    caseSensitive: false,
  );

  /// Information requests (news, weather, prices, sports ...) are answered inside
  /// the app. The phone agent is only for ACTIONS on the phone.
  static final RegExp _infoLike = RegExp(
    r'(هەواڵ|کەش و هەوا|کەشوهەوا|پلەی گەرمی|نرخ|بەهای|دراو|دۆلار|ئەنجامی یاری|وەرزش|news|weather|price|score)',
    caseSensitive: false,
  );

  /// Words that mean "do something on the phone / open an app".
  static final RegExp _actionLike = RegExp(
    r'(بکەرەوە|بکەوە|بکەنەوە|ئەپ|یوتوب|یوتیوب|فەیسبووک|ئینستاگرام|تیکتۆک|واتسئەپ|تێلێگرام|سناپ|'
    r'وێبسایت|مالپەڕ|گووگڵ|کرۆم|براوزەر|website|browser|google|chrome|open|launch)',
    caseSensitive: false,
  );

  /// Clear "do it" verbs: a sentence that has one is a phone task even if it
  /// also contains a question word (e.g. "open TikTok, how many ...").
  static final RegExp _doVerb = RegExp(
    r'(بکەرەوە|بکەوە|بکەنەوە|بدۆزەوە|بخوێنەرەوە|بیخوێنەرەوە|بگەڕێ|سێرچ|بنێرە|بنووسە|لێبدە|open|launch|search|read|play|send)',
    caseSensitive: false,
  );

  /// Local PHONE/CHAT decision: no LLM call (saves one request per command).
  bool _isPhoneTaskLocal(String text) {
    final t = text.trim();
    final isPhone = (_doVerb.hasMatch(t) && _actionLike.hasMatch(t)) ||
        (!_questionLike.hasMatch(t) &&
            !(_infoLike.hasMatch(t) && !_actionLike.hasMatch(t)));
    _toast('TEXO: local classifier -> ${isPhone ? 'PHONE' : 'CHAT'}');
    return isPhone;
  }

  static const MethodChannel _dev = MethodChannel('com.texo.texo/device');

  static final RegExp _musicWords = RegExp(
    r'(گۆرانی|گۆرانییەک|موزیک|میوزیک|مۆزیک|مۆسیقا|یوتوب|یوتیوب|youtube|play)',
    caseSensitive: false,
  );
  static const Set<String> _fillers = {
    'لە', 'یوتوب', 'یوتیوب', 'youtube', 'play', 'گۆرانییەک', 'گۆرانی',
    'موزیک', 'میوزیک', 'مۆزیک', 'مۆسیقا', 'بکەوە', 'بکەرەوە', 'بکەنەوە',
    'لێبدە', 'دابنێ', 'بدۆزەوە', 'بگەڕێ', 'بۆم', 'تکایە', 'ئەپی', 'ئەپ',
    'هەڵکە', 'هەڵبکە', 'بکە', 'بکەن', 'بیکە', 'پەخش', 'پەخشی', 'بخەرە', 'بخە',
    'و', 'ئەو', 'ئەم',
  };
  static const Set<String> _openWords = {'بکەرەوە', 'بکەنەوە', 'بکەوە'};
  static const Map<String, String> _appNames = {
    'یوتوب': 'youtube', 'یوتیوب': 'youtube', 'فەیسبووک': 'facebook',
    'ئینستاگرام': 'instagram', 'تیکتۆک': 'tiktok', 'واتسئەپ': 'whatsapp',
    'تێلێگرام': 'telegram', 'سناپ': 'snapchat',
  };

  static final RegExp _songWord =
      RegExp(r'^گۆرانی(?:ەکی|ەک|ەکە|ەکان|یەکی|یەک)?$');
  static const Set<String> _chatWords = {
    'سڵاو', 'سلاو', 'چۆنیت', 'چۆنی', 'دەتوانی', 'دەتوانیت', 'ئایا',
  };

  /// Search query for a music request. Returns '' when no song is named, or
  /// null for free-form sentences (greetings, long requests): the agent
  /// handles those instead of guessing a query from the whole sentence.
  String? _extractMusicQuery(List<String> tokens) {
    if (tokens.length > 8) return null;
    if (tokens.any((w) => _chatWords.contains(w))) return null;
    const extra = <String>{'بۆ', 'ئێستا', 'ئەمجارە', 'هەر'};
    final songIdx = tokens.indexWhere((w) => _songWord.hasMatch(w));
    final rest = songIdx >= 0 ? tokens.sublist(songIdx + 1) : tokens;
    final q = rest
        .where((w) => !_fillers.contains(w.toLowerCase()) && !extra.contains(w))
        .join(' ')
        .trim();
    if (q.split(' ').where((w) => w.isNotEmpty).length > 4) return null;
    return q;
  }

  /// Id of the first video that YouTube finds for [query] (null if not found).
  Future<String?> _firstYoutubeId(String query) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final uri = Uri.https('www.youtube.com', '/results', {'search_query': query});
      final req = await client.getUrl(uri);
      req.headers.set(
        HttpHeaders.userAgentHeader,
        'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/124.0 Mobile Safari/537.36',
      );
      req.headers.set(HttpHeaders.acceptLanguageHeader, 'en-US,en;q=0.9');
      req.cookies.add(Cookie('CONSENT', 'YES+1'));
      final res = await req.close().timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      final body = await res
          .transform(const Utf8Decoder(allowMalformed: true))
          .join()
          .timeout(const Duration(seconds: 12));
      final m = RegExp(r'"videoRenderer":\{"videoId":"([A-Za-z0-9_-]{11})"').firstMatch(body) ??
          RegExp(r'"videoId":"([A-Za-z0-9_-]{11})"').firstMatch(body);
      return m?.group(1);
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  static const String _pkgYtMusic = 'com.google.android.apps.youtube.music';
  static const String _pkgSpotify = 'com.spotify.music';

  /// Music apps to try in order, so Android never shows the app chooser.
  List<String> _musicPackages(String text) {
    final l = text.toLowerCase();
    final wantsSpotify = l.contains('spotify') ||
        l.contains('سپۆتیفای') ||
        l.contains('سپوتیفای');
    return wantsSpotify
        ? [_pkgSpotify, _pkgYtMusic]
        : [_pkgYtMusic, _pkgSpotify];
  }

  Future<Map<String, dynamic>> _fastCall(
      MethodChannel ch, String m, Map<String, dynamic> a) async {
    try {
      final r = await ch.invokeMethod<dynamic>(m, a);
      if (r is Map) return Map<String, dynamic>.from(r);
      return {'ok': true};
    } on PlatformException catch (e) {
      return {'ok': false, 'error': '${e.code}'};
    } on MissingPluginException {
      return {'ok': false, 'error': 'missing'};
    }
  }

  /// Direct Android intents, no LLM and no screen reading.
  /// Returns a reply text on success, null to fall back to the agent.
  bool _cancelRequested = false;

  Future<String?> _tryFast(String text) async {
    if (_cancelRequested) return null;
    final t = text.trim();
    final lowT = t.toLowerCase();
    var asciiT = lowT;
    const arDigits = '٠١٢٣٤٥٦٧٨٩';
    for (var i = 0; i < 10; i++) {
      asciiT = asciiT.replaceAll(arDigits[i], '$i');
    }
    final noYt = !lowT.contains('یوتوب') && !lowT.contains('یوتیوب') && !lowT.contains('youtube');
    final onPhone = RegExp(r'لە (ناو )?(مۆبایل|مۆبایلەکەم|ئامێر|فایل)|لەسەر مۆبایل|لە گەلەری').hasMatch(lowT);
    final songish = RegExp(r'گۆرانی|موزیک|میوزیک|مۆزیک|song|music').hasMatch(lowT);
    final byLength = RegExp(r'(\d{1,2})\s*[:.]\s*(\d{2})').firstMatch(asciiT);
    if (songish && noYt && (onPhone || byLength != null)) {
      var minMs = 0;
      var maxMs = 0;
      if (byLength != null) {
        final sec = int.parse(byLength.group(1)!) * 60 + int.parse(byLength.group(2)!);
        minMs = (sec - 2) * 1000;
        maxMs = (sec + 2) * 1000;
      }
      const stop = {
        'گۆرانی', 'گۆرانییەک', 'گۆرانیەک', 'گۆرانییەکم', 'گۆرانیەکم', 'گۆرانییەکی', 'گۆرانیەکی',
        'موزیک', 'میوزیک', 'لە', 'ناو', 'مۆبایل', 'مۆبایلەکەم', 'مۆبایلەکە', 'هەیە', 'پێمە', 'پێیە',
        'نووسیومە', 'کۆنەکە', 'ئەوە', 'کە', 'هەڵکە', 'لێبدە', 'بۆم', 'بدۆزەوە', 'دابنێ', 'سانیەیە',
        'چرکەیە', 'خولەکە', 'ماوەکەی', 'ئەو', 'ئەم', 'و', 'بە', 'یەک', 'پەخش', 'بکە',
      };
      final who = lowT
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty && !stop.contains(w) && !RegExp(r'[0-9٠-٩:.]').hasMatch(w))
          .join(' ');
      final r = await _fastCall(_sys, 'searchAudio', {'query': who, 'minMs': minMs, 'maxMs': maxMs});
      if (r['needsPermission'] == true) {
        return 'مۆڵەتی خوێندنەوەی گۆرانییەکانم نەبوو، داوام کرد؛ ڕێگە بدە و دووبارە بیڵێ.';
      }
      if (r['ok'] == false) return 'گەڕان لە گۆرانییەکانی مۆبایل شکستی هێنا.';
      final items = (r['items'] as List?) ?? const [];
      if (items.isEmpty) return 'هیچ گۆرانییەکم نەدۆزییەوە لەو مۆبایلەدا بەو وەسفە.';
      final first = items.first as Map;
      final p = await _fastCall(_sys, 'playAudio', {'id': first['id']});
      final names = items.take(3).map((d) => d is Map ? '${d['title']}' : '').join('، ');
      if (p['ok'] != false && p['error'] == null) {
        return items.length == 1 ? 'لێمدا: ${first['title']}.' : 'یەکەمیانم لێدا (${first['title']}). ئەوانی تر: $names';
      }
      return 'گۆرانییەکەم دۆزییەوە (${first['title']}) بەڵام نەمتوانی لێی بدەم.';
    }
    final callish = RegExp(r'پەیوەندی (بکە|پێوە بکە)|تەلەفۆن (بکە|بۆ)|زەنگ (بۆ|لێبدە)|\bcall\b').hasMatch(lowT);
    if (callish && !lowT.contains('بلوتوس') && !lowT.contains('وایفای') && !lowT.contains('wifi')) {
      const cstop = {
        'پەیوەندی', 'بکە', 'بە', 'بۆ', 'تەلەفۆن', 'زەنگ', 'لێبدە', 'پێوە', 'call', 'تکایە',
        'ئەو', 'ئەم', 'کەسە', 'ژمارەی', 'ژمارە',
      };
      final who = lowT.split(RegExp(r'\s+')).where((w) => w.isNotEmpty && !cstop.contains(w)).join(' ');
      final r = await _fastCall(_sys, 'dialContact', {'query': who});
      if (r['needsPermission'] == true) {
        return 'مۆڵەتی کۆنتاکتەکانم نەبوو، داوام کرد؛ ڕێگە بدە و دووبارە بیڵێ.';
      }
      if (r['error'] == 'not_found') return 'لە کۆنتاکتەکاندا نەمدۆزییەوە: $who';
      if (r['error'] == 'ambiguous') {
        return 'چەند کەسێک دەچن: ${((r['names'] as List?) ?? const []).join('، ')}. کامیان؟';
      }
      if (r['ok'] == false) return 'نەمتوانی ژمارەکە بکەمەوە.';
      return 'ژمارەی ${r['name']}م کردەوە لە دایلەر؛ دوگمەی پەیوەندی دابگرە.';
    }
    final tokens = t.split(RegExp(r'\s+'));
    final hasYoutube = tokens.any((w) {
      final l = w.toLowerCase();
      return l == 'یوتوب' || l == 'یوتیوب' || l == 'youtube';
    });

    if (_musicWords.hasMatch(t)) {
      final q = _extractMusicQuery(tokens);
      if (q == null) return null; // free-form sentence: the agent handles it
      if (q.isEmpty && hasYoutube) {
        final r = await _fastCall(_dev, 'launchApp', {'packageId': 'youtube'});
        return (r['ok'] != false && r['error'] == null) ? 'یوتوبم کردەوە.' : null;
      }
      if (!hasYoutube) {
        await _fastCall(_sys, 'agentBegin', {});
        var r = <String, dynamic>{'ok': false};
        for (final pkg in _musicPackages(t)) {
          r = await _fastCall(_sys, 'a11yStartIntent', {
            'action': 'android.media.action.MEDIA_PLAY_FROM_SEARCH',
            'package': pkg,
            'extras': {
              'query': q,
              'android.intent.extra.focus': 'vnd.android.cursor.item/*',
            },
          });
          if (r['ok'] != false) break;
        }
        await _fastCall(_sys, 'agentEnd', {});
        if (r['ok'] != false) {
          return q.isEmpty ? 'موزیکم دەست پێکرد.' : 'داوای لێدانی «$q»م نارد.';
        }
      }
      if (q.isNotEmpty) {
        // Play the first match directly. If it cannot be found, hand the task
        // to the agent: it opens the search and taps the first video itself.
        final id = await _firstYoutubeId(q);
        if (id != null) {
          final r = await _fastCall(
              _dev, 'launchUrl', {'url': 'https://www.youtube.com/watch?v=$id'});
          if (r['ok'] != false && r['error'] == null) {
            return 'لە یوتوب «$q»م پەخش کرد.';
          }
        }
      }
      return null;
    }

    if (tokens.length >= 2 && _openWords.contains(tokens.last)) {
      final name = tokens
          .sublist(0, tokens.length - 1)
          .where((w) => w != 'ئەپی' && w != 'ئەپ')
          .join('')
          .toLowerCase();
      final pkg = _appNames[name];
      if (pkg != null) {
        final r = await _fastCall(_dev, 'launchApp', {'packageId': pkg});
        if (r['ok'] != false && r['error'] == null) return 'کردمەوە.';
      }
    }

    final low = t.toLowerCase();
    final themeWord = RegExp(r'تێم|ڕەنگی ئەپ|theme|dark mode|light mode|مۆدی تاریک|دارک مۆد').hasMatch(low);
    final wDark = RegExp(r'تاریک|ڕەش|دارک|dark').hasMatch(low);
    final wLight = RegExp(r'ڕووناک|سپی|لایت|light').hasMatch(low);
    if (themeWord && !low.contains('ئۆڤەر') && (wDark != wLight)) {
      themeRequest.value = wDark ? 'dark' : 'light';
      return wDark ? 'تێمی تاریکم دانا.' : 'تێمی ڕووناکم دانا.';
    }
    if ((low.contains('ئۆڤەر') || low.contains('overlay')) &&
        RegExp(r'ڕەنگ|بکە بە|بگۆڕە|color').hasMatch(low)) {
      const colorWords = [
        'ڕەش', 'رەش', 'سپی', 'سوور', 'شین', 'سەوز', 'زەرد', 'مۆر', 'پرتەقاڵی',
        'پەمەیی', 'خۆڵەمێشی', 'ئاسمانی', 'قاوەیی', 'black', 'white', 'red',
        'blue', 'green', 'yellow', 'purple', 'orange', 'pink', 'gray', 'grey',
        'brown', 'sky',
      ];
      String? bgName;
      String? fgName;
      for (final clause in low.split(RegExp(r'\s+و\s+|[،,]'))) {
        if (!colorWords.any((w) => clause.contains(w))) continue;
        if (RegExp(r'دەق|نووسین|فۆنت|text|font').hasMatch(clause)) {
          fgName ??= clause;
        } else {
          bgName ??= clause;
        }
      }
      if (bgName != null || fgName != null) {
        try {
          await _ovColor.invokeMethod<dynamic>('overlayState', <String, dynamic>{
            if (bgName != null) 'bgName': bgName,
            if (fgName != null) 'fgName': fgName,
          });
          return 'ڕەنگەکەم بۆ ئۆڤەرلا نارد (ئەگەر ئۆڤەرلا کراوەیە دەگۆڕێت).';
        } catch (_) {
          return 'نەمتوانی ڕەنگ بنێرم بۆ ئۆڤەرلا.';
        }
      }
    }
    final isBt = low.contains('بلوتوس') || low.contains('بلوتوث') || low.contains('bluetooth');
    final isWifi = RegExp(r'وای ?فای|wifi|wi-fi').hasMatch(low);
    final wantsOn = RegExp(r'هەڵکە|هەڵبکە|چالاک|turn on|enable').hasMatch(low);
    final wantsOff = RegExp(r'بکوژێنەوە|دایبخە|ناچالاک|turn off|disable').hasMatch(low);
    final wantsList = RegExp(r'جووتکراو|paired').hasMatch(low);

    if (isBt && wantsList && !wantsOn && !wantsOff) {
      final r = await _fastCall(_sys, 'listPairedBluetooth', {});
      if (r['needsPermission'] == true) return 'مۆڵەتی بلوتوسم نییە.';
      final devs = r['devices'];
      if (devs is List && devs.isNotEmpty) {
        final names = devs
            .map((d) => d is Map ? (d['name'] ?? '').toString() : '')
            .where((n) => n.isNotEmpty)
            .join('، ');
        return 'ئامێرە جووتکراوەکان: $names';
      }
      if (devs is List) return 'هیچ ئامێرێکی جووتکراو نییە.';
    }
    if ((isBt || isWifi) && (wantsOn || wantsOff)) {
      final r = await _fastCall(
          _sys, isBt ? 'setBluetoothEnabled' : 'setWifiEnabled', {'enable': wantsOn});
      if (r['ok'] != false && r['error'] == null) {
        if (r['requiresUserAction'] == true || r['method'] == 'settings_panel') {
          return 'پانێلەکەم کردەوە، خۆت بیگۆڕە.';
        }
        return wantsOn ? 'هەڵمکرد.' : 'کوژاندمەوە.';
      }
    }

    if (RegExp(r'فلاش|فڵاش|flashlight|torch|چرای مۆبایل').hasMatch(low)) {
      final tOn = RegExp(r'هەڵکە|هەڵبکە|بگیرسێنە|turn on|\bon\b').hasMatch(low);
      final tOff = RegExp(r'بکوژێنەوە|بیکوژێنەوە|دایبخە|turn off|\boff\b').hasMatch(low);
      if (tOn != tOff) {
        final r = await _fastCall(_sys, 'torch', {'on': tOn});
        if (r['ok'] != false && r['error'] == null) return tOn ? 'فلاشم هەڵکرد.' : 'فلاشم کوژاندەوە.';
        return 'نەمتوانی فلاش بگۆڕم (${r['error'] ?? 'نەزانراو'}).';
      }
    }

    if (isBt && !wantsOn && !wantsOff) {
      if (RegExp(r'نزیک|دەوروبەر|بدۆزەوە|بگەڕێ|scan|nearby').hasMatch(low)) {
        final r = await _fastCall(_sys, 'scanBluetooth', {});
        if (r['needsPermission'] == true) {
          return 'مۆڵەتی گەڕانی بلوتوسم نەبوو، داوام کرد؛ ڕێگە بدە و دووبارە بیڵێ.';
        }
        if (r['ok'] == false) {
          return r['error'] == 'bluetooth_off' ? 'بلوتوس کوژاوەتەوە؛ یەکەم هەڵی بکە.' : 'گەڕانی بلوتوس نەستا.';
        }
        final devs = (r['devices'] as List?) ?? const [];
        if (devs.isEmpty) {
          return 'هیچ ئامێرێکی نزیکم نەدۆزییەوە؛ دڵنیابە ئامێرەکە لە دۆخی جووتبوون (pairing) دایە.';
        }
        final names = devs
            .take(5)
            .map((d) => d is Map ? ('${d['name']}'.isEmpty ? 'بێ ناو' : '${d['name']}') : '')
            .join('، ');
        return 'نزیکترین ئامێرەکان: $names. بڵێ «پەیوەست بە» و ناوی ئامێرەکە.';
      }
      if (RegExp(r'پەیوەست|جووت بکە|connect|pair').hasMatch(low)) {
        final r = await _fastCall(_sys, 'bondBluetooth', {'query': low});
        if (r['needsPermission'] == true) return 'مۆڵەتی بلوتوسم نەبوو، داوام کرد؛ ڕێگە بدە و دووبارە بیڵێ.';
        if (r['error'] == 'no_scan') return 'یەکەم بڵێ «ئامێرە نزیکەکان بدۆزەوە».';
        if (r['error'] == 'ambiguous') {
          return 'کامیان؟ ${((r['names'] as List?) ?? const []).join('، ')}';
        }
        if (r['ok'] == false) return 'نەمتوانی جووتی بکەم.';
        return 'داوای جووتکردنی ${r['name']}م نارد؛ ئەگەر پەنجەرەیەک هات «Pair» بدە.';
      }
    }
    return null;
  }

  Future<bool> _isPhoneTask(String text) async {
    try {
      final out = await _llm(
        'Reply with exactly one word: PHONE or CHAT.',
        'Decide if the user message asks to operate the phone itself '
        '(open an app, play something in an app, search inside an app, set an '
        'alarm, change a setting, navigate to a page, send a message, call '
        'someone, etc.) or is just conversation / a general question.\n\n'
        'Message: $text',
      );
      final isPhone = out.toUpperCase().contains('PHONE');
      _toast('TEXO: classifier -> ${isPhone ? 'PHONE' : 'CHAT'}');
      return isPhone;
    } catch (e) {
      _toast('TEXO: classifier error: $e');
      return false;
    }
  }

  Future<String> _llm(String system, String user) async {
    final cfg = AgentConfig(
      id: 'phone_agent',
      name: 'Phone Agent',
      description: 'Phone control agent',
      systemPrompt: system,
      modelId: _modelId,
      temperature: 0.2,
      maxTokens: 2048,
    );
    final res = await providerGetter().complete(
      AIRequest(
        prompt: user,
        agentConfig: cfg,
        messages: [
          AIMessage.fromMap({'role': 'user', 'content': user}),
        ],
        temperature: 0.2,
        maxTokens: 2048,
      ),
    );
    return res.text;
  }

  Future<bool> _consent(String reason) async {
    try {
      final r = await _sys.invokeMethod<dynamic>('agentAsk', {'message': reason});
      return r is Map && r['allowed'] == true;
    } catch (_) {
      return false;
    }
  }

  void _toast(String m) {
    final msg = m.length > 140 ? m.substring(0, 140) : m;
    _sys
        .invokeMethod<dynamic>('agentToast', {'message': msg})
        .catchError((_) {});
  }
}
