"""Deletes the OLD design files that nothing uses any more.

Safe by construction: it builds the import graph and only deletes files in
lib/presentation/screens and lib/presentation/widgets that are NOT reachable from
  - lib/main.dart, lib/ui/**, lib/bridge/**   (the new app)
  - anything related to vision, pose, exercise, camera, alarm   (kept features)
Default is a DRY RUN. Add --apply to really delete.
Run from the project root:  python3 tools/delete_old_design.py [--apply]"""
import os
import re
import sys

APPLY = "--apply" in sys.argv
PROTECT = re.compile(r"vision|pose|exercise|camera|alarm|wake", re.I)
CAND_DIRS = ("lib/presentation/screens", "lib/presentation/widgets")
IMPORT_RE = re.compile(r"""^\s*(?:import|export|part)\s+['"]([^'"]+)['"]""", re.M)

pkg = "texo"
try:
    for line in open("pubspec.yaml", encoding="utf-8"):
        if line.startswith("name:"):
            pkg = line.split(":", 1)[1].strip()
            break
except OSError:
    pass

files = []
for root, _, names in os.walk("lib"):
    for n in names:
        if n.endswith(".dart"):
            files.append(os.path.normpath(os.path.join(root, n)))
fileset = set(files)


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


graph = {}
for f in files:
    try:
        text = open(f, encoding="utf-8").read()
    except OSError:
        text = ""
    graph[f] = [r for r in (resolve(f, m) for m in IMPORT_RE.findall(text)) if r]

roots = [f for f in files if f == os.path.normpath("lib/main.dart")
         or f.startswith(os.path.normpath("lib/ui") + os.sep)
         or f.startswith(os.path.normpath("lib/bridge") + os.sep)
         or PROTECT.search(os.path.basename(f))]
seen = set()
stack = list(roots)
while stack:
    f = stack.pop()
    if f in seen:
        continue
    seen.add(f)
    stack.extend(graph.get(f, []))

cands = [f for f in files if f.startswith(tuple(os.path.normpath(d) + os.sep for d in CAND_DIRS))]
delete = sorted(f for f in cands if f not in seen)
keep = sorted(f for f in cands if f in seen)
print("candidates:", len(cands), "| will delete:", len(delete), "| kept (still used):", len(keep))
print("\n== KEPT ==")
for f in keep:
    print("  keep  ", f)
print("\n== DELETE ==")
for f in delete:
    print("  delete", f)
if APPLY:
    for f in delete:
        os.remove(f)
    print("\ndeleted", len(delete), "files. Now run the compile check (git push -> ui_analyze.txt).")
else:
    print("\n(dry run) nothing deleted. Re-run with --apply to delete.")
