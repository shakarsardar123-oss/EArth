/// Pure parsing for Sorani reminder phrases. Not imported anywhere yet,
/// so it cannot affect the APK build until it is wired in.
DateTime? parseReminderTime(String input, DateTime now) {
  final s = _toLatinDigits(input.trim());

  final rel = RegExp(r'دوای\s*(\d+)\s*(خولەک|کاتژمێر)').firstMatch(s);
  if (rel != null) {
    final n = int.parse(rel.group(1)!);
    return rel.group(2) == 'کاتژمێر'
        ? now.add(Duration(hours: n))
        : now.add(Duration(minutes: n));
  }

  final abs = RegExp(r'(\d{1,2})(?::(\d{2}))?\s*ی?\s*(بەیانی|نیوەڕۆ|ئێوارە|شەو)?')
      .firstMatch(s);
  if (abs == null) return null;

  var h = int.parse(abs.group(1)!);
  final m = abs.group(2) == null ? 0 : int.parse(abs.group(2)!);
  final part = abs.group(3);
  if (h > 23 || m > 59) return null;

  if ((part == 'ئێوارە' || part == 'شەو') && h < 12) h += 12;
  if (part == 'بەیانی' && h == 12) h = 0;
  if (part == 'نیوەڕۆ' && h < 12) h = 12;

  var t = DateTime(now.year, now.month, now.day, h, m);
  if (!t.isAfter(now)) t = t.add(const Duration(days: 1));
  return t;
}

String _toLatinDigits(String s) {
  const ku = '٠١٢٣٤٥٦٧٨٩';
  var out = s;
  for (var i = 0; i < 10; i++) {
    out = out.replaceAll(ku[i], '$i');
  }
  return out;
}
