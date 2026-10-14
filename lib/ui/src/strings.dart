import 'package:flutter/material.dart';

/// All UI text in Kurdish (Sorani, RTL) and English (LTR).
class UiStrings {
  const UiStrings(this.lang);

  final String lang;

  bool get isKu => lang == 'ku';
  TextDirection get dir => isKu ? TextDirection.rtl : TextDirection.ltr;

  String t(String key) => (isKu ? _ku : _en)[key] ?? key;

  String greeting(String name) =>
      isKu ? 'با دەست پێ بکەین، $name' : 'Let\u2019s jump in, $name';

  /// Western digits -> Arabic-Indic digits when the UI is Kurdish.
  String digits(String input) {
    if (!isKu) return input;
    const String from = '0123456789';
    const String to = '\u0660\u0661\u0662\u0663\u0664\u0665\u0666\u0667\u0668\u0669';
    final StringBuffer out = StringBuffer();
    for (final int rune in input.runes) {
      final String ch = String.fromCharCode(rune);
      final int i = from.indexOf(ch);
      out.write(i >= 0 ? to[i] : ch);
    }
    return out.toString();
  }

  static const Map<String, String> _ku = <String, String>{
    'brand': 'تێکسۆ',
    'menu': 'مینیو',
    'model': 'تێکسۆ ئۆتۆ',
    'newChat': 'چاتی نوێ',
    'ask': 'لە تێکسۆ بپرسە...',
    'attach': 'هاوپێچکردن',
    'mic': 'مایک',
    'live': 'دەنگی زیندوو',
    'back': 'گەڕانەوە',
    'close': 'کۆتاییهێنان',
    's1': 'یوتوب بکەرەوە و گۆرانی بدۆزەوە',
    's2': 'کامێرا بکەرەوە و بپرسە «ئەمە چییە؟»',
    's3': 'کاتژمێری بێدارکەرەوە بۆ بەیانی دابنێ',
    's1prompt': 'یوتوب بکەرەوە و گۆرانی بدۆزەوە',
    's3prompt': 'کاتژمێری بێدارکەرەوە بۆ بەیانی دابنێ',
    'listening': 'گوێم لێتە...',
    'thinking': 'بیر دەکەمەوە...',
    'speaking': 'قسە دەکەم...',
    'hint': 'قسە بکە، من گوێم لێتە و یارمەتیت دەدەم',
    'chatTitle': 'چاتێکی نوێ',
    'historyTitle': 'مێژووی چاتەکان',
    'search': 'گەڕان لە چاتەکان...',
    'settings': 'ڕێکخستنەکان',
    'seeAll': 'هەمووی',
    'recent': 'دوایین چاتەکان',
    'today': 'ئەمڕۆ',
    'yesterday': 'دوێنێ',
    'week': '٧ ڕۆژی ڕابردوو',
    'older': 'کۆنتر',
    'send': 'ناردن',
    'copy': 'کۆپی',
    'read': 'بیخوێنەوە',
    'retry': 'دووبارە وەڵام بدەرەوە',
    'working': 'خەریکی ئەنجامدانم...',
    'empty': 'هێشتا هیچ چاتێک نییە',
    'language': 'زمان',
    'langNote': 'ئاراستەی ڕووکار و ئایکۆنەکان بە شێوەی خۆکار دەگۆڕێن.',
    'appearance': 'ڕووکار',
    'light': 'ڕووناک',
    'dark': 'تاریک',
    'system': 'سیستەم',
    'voice': 'دەنگ',
    'wake': 'بانگکردن بە «تێکسۆ»',
    'wakeSub': 'بێ دەست پێکردنی ئەپەکە',
    'readAloud': 'خوێندنەوەی وەڵامەکان',
    'readSub': 'بە دەنگی کوردی',
    'haptics': 'لەرین',
    'hapSub': 'لەکاتی گوێگرتن',
    'permissions': 'مۆڵەتەکان',
    'overlay': 'پەنجەرەی سەرەوە',
    'overlaySub': 'نیشاندانی تێکسۆ لەسەر ئەپەکانی تر',
    'access': 'گەیشتن بە شاشە',
    'accessSub': 'بۆ کردنەوەی ئەپ و خوێندنەوەی شاشە',
    'on': 'چالاک',
    'off': 'ناچالاک',
    'version': 'وەشانی ٠.٩',
    'apiKey': 'کلیلی API',
    'apiKeySub': 'بۆ پەیوەندی بە Gemini',
    'apiKeyHint': 'کلیلەکە لێرە بنووسە',
    'save': 'پاشەکەوتکردن',
    'cancel': 'هەڵوەشاندنەوە',
    'keySet': 'دانراوە',
    'keyMissing': 'دانەنراوە',
  };

  static const Map<String, String> _en = <String, String>{
    'brand': 'TEXO',
    'menu': 'Menu',
    'model': 'TEXO Auto',
    'newChat': 'New chat',
    'ask': 'Ask TEXO...',
    'attach': 'Attach',
    'mic': 'Microphone',
    'live': 'Live voice',
    'back': 'Back',
    'close': 'End',
    's1': 'Open YouTube and find a song',
    's2': 'Open the camera and ask \u201cwhat is this?\u201d',
    's3': 'Set a morning alarm for me',
    's1prompt': 'Open YouTube and find a song',
    's3prompt': 'Set a morning alarm for me',
    'listening': 'Listening...',
    'thinking': 'Thinking...',
    'speaking': 'Speaking...',
    'hint': 'Just speak \u2014 I\u2019m listening and ready to help',
    'chatTitle': 'New chat',
    'historyTitle': 'Chat history',
    'search': 'Search chats...',
    'settings': 'Settings',
    'seeAll': 'See all',
    'recent': 'Recent chats',
    'today': 'Today',
    'yesterday': 'Yesterday',
    'week': 'Previous 7 days',
    'older': 'Older',
    'send': 'Send',
    'copy': 'Copy',
    'read': 'Read aloud',
    'retry': 'Regenerate',
    'working': 'Working on it...',
    'empty': 'No chats yet',
    'language': 'Language',
    'langNote': 'Layout direction and icons switch automatically.',
    'appearance': 'Appearance',
    'light': 'Light',
    'dark': 'Dark',
    'system': 'System',
    'voice': 'Voice',
    'wake': 'Wake word \u201cTEXO\u201d',
    'wakeSub': 'Hands-free start',
    'readAloud': 'Read replies aloud',
    'readSub': 'In Kurdish voice',
    'haptics': 'Vibration',
    'hapSub': 'While listening',
    'permissions': 'Permissions',
    'overlay': 'Floating window',
    'overlaySub': 'Show TEXO over other apps',
    'access': 'Screen access',
    'accessSub': 'To open apps and read the screen',
    'on': 'On',
    'off': 'Off',
    'version': 'Version 0.9',
    'apiKey': 'API key',
    'apiKeySub': 'To connect to Gemini',
    'apiKeyHint': 'Paste the key here',
    'save': 'Save',
    'cancel': 'Cancel',
    'keySet': 'Set',
    'keyMissing': 'Not set',
  };
}
