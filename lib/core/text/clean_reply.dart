/// Helpers for answers that stream in piece by piece.
library;

/// Removes markdown symbols (stars, headings, code fences) so they are never
/// shown on screen or read aloud. Safe to call on a half-finished answer.
String cleanReply(String t) {
  var s = t.replaceAll('\r', '');
  s = s.replaceAll(RegExp(r'```[\s\S]*?(```|$)'), ' ');
  s = s.replaceAll(RegExp(r'^\s{0,3}#{1,6}\s*', multiLine: true), '');
  s = s.replaceAll(RegExp(r'^\s*[*\-]\s+', multiLine: true), '\u2022 ');
  s = s.replaceAll(RegExp(r'[*_`~]+'), '');
  s = s.replaceAll(RegExp(r'[ \t]{2,}'), ' ');
  s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return s.trim();
}

/// Cuts a growing text into sentences so the first one can be spoken while the
/// rest is still being written.
class SentenceSplitter {
  final StringBuffer _buf = StringBuffer();
  bool _first = true;

  List<String> add(String chunk) {
    _buf.write(chunk);
    return _drain(false);
  }

  List<String> flush() => _drain(true);

  List<String> _drain(bool all) {
    final List<String> out = <String>[];
    final String s = _buf.toString();
    int start = 0;
    for (int i = 0; i < s.length; i++) {
      final String c = s[i];
      final bool term =
          c == '.' || c == '!' || c == '?' || c == '\u061F' || c == '\n';
      if (!term) continue;
      final bool nextIsSpace = i + 1 < s.length && (s[i + 1] == ' ' || s[i + 1] == '\n');
      final bool atEnd = i + 1 >= s.length;
      if (nextIsSpace || (atEnd && all)) {
        final String piece = s.substring(start, i + 1).trim();
        if (piece.length >= (_first ? 8 : 14)) {
          out.add(piece);
          start = i + 1;
          _first = false;
        }
      }
    }
    String rest = s.substring(start);
    if (all && rest.trim().isNotEmpty) {
      out.add(rest.trim());
      rest = '';
    }
    _buf
      ..clear()
      ..write(rest);
    return out;
  }
}

/// The offline recogniser sometimes loops ("خۆی خۆی خۆی خۆی ..."). Keeps one copy
/// of any word or word pair that is repeated three or more times in a row.
String collapseRepeats(String t) {
  final List<String> words =
      t.split(RegExp(r'\s+')).where((String w) => w.isNotEmpty).toList();
  final List<String> out = <String>[];
  for (final String w in words) {
    if (out.length >= 2 && out[out.length - 1] == w && out[out.length - 2] == w) continue;
    out.add(w);
  }
  String s = out.join(' ');
  s = s.replaceAllMapped(RegExp(r'(\S+ \S+)( \1){2,}'), (Match m) => m[1]!);
  return s.trim();
}

/// "Sunday 2026-11-01 15:30" for the assistant, so it can answer date questions.
String nowForAssistant() {
  final DateTime n = DateTime.now();
  const List<String> days = <String>[
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];
  String two(int v) => v.toString().padLeft(2, '0');
  return '${days[n.weekday - 1]} ${n.year}-${two(n.month)}-${two(n.day)} ${two(n.hour)}:${two(n.minute)}';
}
