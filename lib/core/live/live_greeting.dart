/// Time-of-day greeting for Live start. Pure text, not wired yet.
String liveGreeting(DateTime now) {
  final h = now.hour;
  if (h >= 5 && h < 12) return 'بەیانیت باش گەورەم. چیت پێویستە؟';
  if (h >= 12 && h < 17) return 'نیوەڕۆت باش گەورەم. چیت پێویستە؟';
  if (h >= 17 && h < 21) return 'ئێوارەت باش گەورەم. چیت پێویستە؟';
  return 'شەوت باش گەورەم. چیت پێویستە؟';
}
