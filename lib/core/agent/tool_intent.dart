// Decides whether a spoken or typed request needs the TOOLS (alarm, timer,
// reminder, call, message, device settings, calendar, maps, ...).
//
// Why this exists: the fast streamed chat path sends a plain request to the
// model WITHOUT any tool declarations, so a request such as "set an alarm"
// was answered in words and nothing was ever done. Requests that look like a
// task now skip the plain stream and go to the agent engine, which has the
// tools. Everything else (stories, questions, chat) is still streamed.

String _norm(String t) {
  String s = t.toLowerCase();
  s = s
      .replaceAll('\u064A', '\u06CC') // Arabic yeh -> Kurdish yeh
      .replaceAll('\u0649', '\u06CC')
      .replaceAll('\u0643', '\u06A9') // Arabic kaf -> Kurdish kaf
      .replaceAll('\u200C', '') // zero width non-joiner
      .replaceAll('\u200D', '')
      .replaceAll(RegExp('[\u064B-\u065F\u0670]'), ''); // diacritics
  return s;
}

// Kurdish (Sorani) and English stems. A match anywhere in the text counts.
const List<String> _toolStems = <String>[
  // alarm / timer / reminder
  'ئەلارم', 'ئه‌لارم', 'بێدارم بکەرەوە', 'زەنگی بێدار', 'تایمەر', 'تایمر',
  'بیرم بخەرەوە', 'بیرم بێنەرەوە', 'بیرخستنەوە', 'بیرهێنەرەوە',
  'alarm', 'timer', 'remind', 'wake me',
  // calls / messages / mail
  'زەنگ بۆ', 'زەنگ لێبدە', 'پەیوەندی بکە', 'پەیوەندی بە', 'تەلەفۆن بکە',
  'نامە بنێرە', 'پەیام بنێرە', 'مەسج', 'مەسێج', 'واتساپ', 'ئیمەیڵ', 'ئیمەیل',
  'تێلیگرام', 'whatsapp', 'sms', 'telegram', 'e-mail', 'email', 'call ',
  'send a message', 'text ',
  // device controls
  'فلاش', 'چرای مۆبایل', 'چراکە', 'دەنگ بەرز', 'دەنگ نزم', 'دەنگەکە',
  'ڕووناکی', 'ڕوناکی', 'وای فای', 'وایفای', 'بلوتوس', 'بلووتوس', 'فڕۆکە',
  'wifi', 'wi-fi', 'bluetooth', 'volume', 'brightness', 'flashlight', 'torch',
  'airplane', 'do not disturb', 'مەپەرێنە',
  // screenshots / camera
  'سکرین شات', 'سکرینشۆت', 'وێنە بگرە', 'screenshot', 'take a photo', 'take a picture',
  // notes / calendar / events
  'تێبینی', 'نۆت', 'یاداشت', 'ڕۆژژمێر', 'ڕۆژنامە', 'کۆبوونەوە', 'ئاگادارکردنەوە دابنێ',
  'note', 'calendar', 'event', 'meeting', 'schedule',
  // maps / navigation
  'ڕێگا بۆ', 'ڕێگای', 'نەخشە', 'ڕێنمایی بکە بۆ', 'map', 'navigate', 'directions',
  // music / media
  'مۆسیقا', 'گۆرانی', 'لێبدە', 'play ', 'pause', 'next song',
  // open / close apps and settings
  'بکەرەوە', 'بیکوژێنەرەوە', 'دایبخە', 'ڕێکخستنەکان', 'open ', 'close ', 'settings',
  // generic "do it" verbs that mean an action on the phone
  'دابنێ', 'بخەرە سەر', 'ڕایبگرە', 'بەرزی بکەرەوە', 'نزمی بکەرەوە',
  'set an', 'set a ', 'turn on', 'turn off', 'switch on', 'switch off',
];

// True when [text] is a request for an action that needs tools.
bool looksLikeToolTask(String text) {
  final String s = _norm(text.trim());
  if (s.isEmpty) return false;
  for (final String stem in _toolStems) {
    if (s.contains(_norm(stem))) return true;
  }
  return false;
}
