"""Patches lib/core/ai/gemini_provider.dart so the Gemini request can carry
(1) file attachments (metadata['attachments']) and (2) the live camera frame.
Run from the project root:  python3 tools/patch_gemini.py
Each part is applied only if its anchor is found exactly once."""
import re
import sys

P = "lib/core/ai/gemini_provider.dart"
s = open(P, encoding="utf-8").read()
done = []

if "LiveVisionFrame" in s:
    print("already patched")
    sys.exit(0)

# --- (1) attachments ---------------------------------------------------------------
A = """        contents.add({
          'role': 'user',
          'parts': [
            {'text': msg.content},
          ],
        });"""
A_NEW = """        final userParts = <Map<String, dynamic>>[
          {'text': msg.content},
        ];
        final attached = msg.metadata?['attachments'];
        if (attached is List) {
          for (final a in attached) {
            if (a is Map && a['data'] is String && a['mime'] is String) {
              userParts.add({
                'inlineData': {'mimeType': a['mime'], 'data': a['data']},
              });
            }
          }
        }
        contents.add({'role': 'user', 'parts': userParts});"""
if s.count(A) == 1:
    s = s.replace(A, A_NEW)
    done.append("attachments")
else:
    print("SKIP attachments: anchor count =", s.count(A))

# --- (2) live camera frame -------------------------------------------------------------
ret = re.findall(r"^[ \t]*return contents;[ \t]*$", s, re.M)
if len(ret) == 1:
    m = re.search(r"^([ \t]*)return contents;[ \t]*$", s, re.M)
    ind = m.group(1)
    block = (
        "{i}// LIVE-VISION: attach the current camera frame to the last user text message.\n"
        "{i}final liveFrame = LiveVisionFrame.fresh();\n"
        "{i}if (liveFrame != null) {{\n"
        "{i}  for (var i = contents.length - 1; i >= 0; i--) {{\n"
        "{i}    final c = contents[i];\n"
        "{i}    final parts = c['parts'];\n"
        "{i}    if (c['role'] == 'user' &&\n"
        "{i}        parts is List &&\n"
        "{i}        parts.any((p) => p is Map && p.containsKey('text'))) {{\n"
        "{i}      final np = <dynamic>[\n"
        "{i}        ...parts,\n"
        "{i}        {{'text': '(The next image is the live camera view from the user\\'s phone right now.)'}},\n"
        "{i}        {{'inlineData': {{'mimeType': 'image/jpeg', 'data': base64Encode(liveFrame)}}}},\n"
        "{i}      ];\n"
        "{i}      contents[i] = <String, dynamic>{{...c, 'parts': np}};\n"
        "{i}      break;\n"
        "{i}    }}\n"
        "{i}  }}\n"
        "{i}}}\n"
    ).format(i=ind)
    s = s[:m.start()] + block + s[m.start():]
    done.append("live-frame")
else:
    print("SKIP live-frame: 'return contents;' count =", len(ret))

if done:
    imports = list(re.finditer(r"^import .*;[ \t]*$", s, re.M))
    add = ""
    if "import 'dart:convert';" not in s:
        add += "import 'dart:convert';\n"
    add += "import '../vision/live_vision_frame.dart';\n"
    if imports:
        last = imports[-1]
        s = s[:last.end()] + "\n" + add.rstrip("\n") + s[last.end():]
    else:
        s = add + s
    open(P, "w", encoding="utf-8").write(s)
    print("OK, patched:", ", ".join(done))
else:
    print("FAIL: nothing patched")
