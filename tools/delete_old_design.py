"""Deletes the OLD design files that nothing uses any more (v2: symbol level).

A file in lib/presentation/screens or lib/presentation/widgets is deleted only if
NO live file uses any class/provider/function it declares. Live files are:
  - lib/main.dart, lib/ui/**, lib/bridge/**                  (the new app)
  - kept features: vision, camera, pose, exercise, alarm, wake
  - kept helpers (until the new Settings replaces them):
    api_key_settings_section, permissions_section, name_editor, theme_selector
Barrel files (only `export` lines) stay if anything imports them; their export
lines pointing to deleted files are removed. Imports of deleted files are removed
from live files (they are unused by definition).

Default is a DRY RUN. Add --apply to really change files.
Run from the project root:  python3 tools/delete_old_design.py [--apply]"""
import os
import re
import sys

APPLY = "--apply" in sys.argv
KEEP_RE = re.compile(
    r"vision|camera|pose|exercise|alarm|wake|api_key_settings_section|permissions_section|name_editor|theme_selector",
    re.I,
)
CAND_DIRS = tuple(os.path.normpath(d) + os.sep for d in ("lib/presentation/screens", "lib/presentation/widgets"))
DIRECTIVE_RE = re.compile(r"""^[ \t]*(import|export|part)[ \t]+['"]([^'"]+)['"][^;]*;[ \t]*\n?""", re.M)
DECL_RES = [
    re.compile(r"^[ \t]*(?:(?:abstract|sealed|base|final|interface|mixin)[ \t]+)*class[ \t]+(\w+)", re.M),
    re.compile(r"^[ \t]*enum[ \t]+(\w+)", re.M),
    re.compile(r"^[ \t]*mixin[ \t]+(\w+)", re.M),
    re.compile(r"^[ \t]*typedef[ \t]+(\w+)", re.M),
    re.compile(r"^(?:final|const|var|late)[ \t]+(?:[\w<>?,. ]+?[ \t]+)?(\w+)[ \t]*=", re.M),
    re.compile(r"^(?:Future<[\w<>?, ]*>|Future|Stream<[\w<>?, ]*>|void|bool|int|double|String|Widget|[A-Z]\w*(?:<[\w<>?, ]*>)?\??)[ \t]+(\w+)[ \t]*\(", re.M),
]
EXT_RE = re.compile(r"^[ \t]*extension\b", re.M)
TOKEN_RE = re.compile(r"[A-Za-z_]\w*")

pkg = "texo"
try:
    for line in open("pubspec.yaml", encoding="utf-8"):
        if line.startswith("name:"):
            pkg = line.split(":", 1)[1].strip()
            break
except OSError:
    pass

files = sorted(os.path.normpath(os.path.join(r, n)) for r, _, ns in os.walk("lib") for n in ns if n.endswith(".dart"))
fileset = set(files)
text = {}
for f in files:
    try:
        text[f] = open(f, encoding="utf-8").read()
    except OSError:
        text[f] = ""


def resolve(frm, spec):
    if spec.startswith("dart:"):
        return None
    if spec.startswith("package:"):
        prefix = "package:%s/" % pkg
        if not spec.startswith(prefix):
            return None
        path = os.path.normpath(os.path.join("lib", spec[len(prefix):]))
    else:
        path = os.path.normpath(os.path.join(os.path.dirname(frm), spec))
    return path if path in fileset else None


imports, exports, parts = {}, {}, {}
for f in files:
    imports[f], exports[f], parts[f] = [], [], []
    for kind, spec in ((m.group(1), m.group(2)) for m in DIRECTIVE_RE.finditer(text[f])):
        t = resolve(f, spec)
        if t:
            {"import": imports, "export": exports, "part": parts}[kind][f].append(t)

declared = {}
for f in files:
    names = set()
    for rx in DECL_RES:
        names.update(rx.findall(text[f]))
    declared[f] = names
tokens = {f: set(TOKEN_RE.findall(text[f])) for f in files}
has_ext = {f: bool(EXT_RE.search(text[f])) for f in files}
is_barrel = {f: (not declared[f]) and bool(exports[f]) for f in files}


def export_closure(g, seen=None):
    seen = seen if seen is not None else set()
    if g in seen:
        return seen
    seen.add(g)
    for e in exports[g]:
        export_closure(e, seen)
    return seen


roots = [f for f in files if f == os.path.normpath("lib/main.dart")
         or f.startswith(os.path.normpath("lib/ui") + os.sep)
         or f.startswith(os.path.normpath("lib/bridge") + os.sep)
         or KEEP_RE.search(os.path.basename(f))]
live = set()
stack = list(roots)
while stack:
    f = stack.pop()
    if f in live:
        continue
    live.add(f)
    stack.extend(parts[f])
    visible = set()
    for i in imports[f]:
        visible |= export_closure(i)
        if is_barrel[i]:
            stack.append(i)
    for g in visible:
        if g == f or g in live:
            continue
        if has_ext[g] or (declared[g] & tokens[f]):
            stack.append(g)

cands = [f for f in files if f.startswith(CAND_DIRS)]
delete = sorted(f for f in cands if f not in live)
keep = sorted(f for f in cands if f in live)
dset = set(delete)

print("candidates:", len(cands), "| will delete:", len(delete), "| kept:", len(keep))
print("\n== KEPT ==")
for f in keep:
    print("  keep  ", f)
print("\n== DELETE ==")
for f in delete:
    print("  delete", f)

edits = {}
for f in files:
    if f in dset:
        continue
    new = text[f]
    for m in list(DIRECTIVE_RE.finditer(text[f])):
        t = resolve(f, m.group(2))
        if t in dset:
            new = new.replace(m.group(0), "", 1)
    if new != text[f]:
        edits[f] = new
print("\n== import/export lines removed in live files (they pointed to deleted files) ==")
for f in sorted(edits):
    print("  edit  ", f)

if APPLY:
    for f, new in edits.items():
        open(f, "w", encoding="utf-8").write(new)
    for f in delete:
        os.remove(f)
    print("\ndone: deleted", len(delete), "files, edited", len(edits), "files. Now push and read ui_analyze.txt.")
else:
    print("\n(dry run) nothing changed. Re-run with --apply.")
