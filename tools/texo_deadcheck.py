#!/usr/bin/env python3
"""
TEXO dead-code checker.

Walks the real import graph of the Flutter app (import / export / part, also
conditional imports) starting from lib/main.dart and reports:

  * Dart files that the app can never reach ("dead" files), by feature folder
  * references to files that do not exist (what is missing)
  * packages that are imported but not declared in pubspec.yaml

Usage (in the project folder):
    python3 texo_deadcheck.py [project_dir] [report_file]
        -> report only, nothing is changed

    python3 texo_deadcheck.py . report.txt --quarantine features/advanced_agent,features/tool_registry
        -> shows which DEAD files of those folders would be moved to archive/
           (reachable files are never touched). Add --yes to really move them.
"""
import os
import re
import sys
from collections import defaultdict

import argparse
import shutil
import subprocess

_ap = argparse.ArgumentParser()
_ap.add_argument("root", nargs="?", default=".")
_ap.add_argument("report", nargs="?")
_ap.add_argument("--quarantine", default="")
_ap.add_argument("--yes", action="store_true")
_args = _ap.parse_args()

ROOT = os.path.abspath(_args.root)
REPORT = _args.report
LIB = os.path.join(ROOT, "lib")

DIRECTIVE = re.compile(r"(?m)^[ \t]*(import|export|part)[ \t]+((?!of\b)[^;]+);")
QUOTED = re.compile(r"""['"]([^'"]+)['"]""")


def read(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            return f.read()
    except OSError:
        return ""


def package_name():
    m = re.search(r"(?m)^name:\s*([A-Za-z0-9_]+)", read(os.path.join(ROOT, "pubspec.yaml")))
    return m.group(1) if m else ""


def declared_packages():
    names = set()
    text = read(os.path.join(ROOT, "pubspec.yaml"))
    block = None
    for line in text.splitlines():
        if re.match(r"^(dependencies|dev_dependencies|dependency_overrides):", line):
            block = line.split(":")[0]
            continue
        if re.match(r"^\S", line) and not line.startswith("#"):
            block = None
        if block:
            m = re.match(r"^  ([A-Za-z0-9_]+):", line)
            if m:
                names.add(m.group(1))
    return names


PKG = package_name()
DECLARED = declared_packages()


def all_dart_files():
    out = []
    for base, _dirs, files in os.walk(LIB):
        for f in files:
            if f.endswith(".dart"):
                out.append(os.path.normpath(os.path.join(base, f)))
    return sorted(out)


def resolve(from_file, uri):
    """Returns (kind, value): ('file', path) | ('ext', pkg) | ('skip', None)"""
    if uri.startswith("dart:"):
        return "skip", None
    if uri.startswith("package:"):
        rest = uri[len("package:"):]
        name, _, path = rest.partition("/")
        if name == PKG:
            return "file", os.path.normpath(os.path.join(LIB, path))
        return "ext", name
    return "file", os.path.normpath(os.path.join(os.path.dirname(from_file), uri))


FILES = all_dart_files()
FILESET = set(FILES)
graph = {}
missing = []          # (file, uri)
ext_used = defaultdict(set)  # package -> files

for f in FILES:
    deps = set()
    for m in DIRECTIVE.finditer(read(f)):
        for q in QUOTED.findall(m.group(2)):
            kind, val = resolve(f, q)
            if kind == "file":
                if val in FILESET:
                    deps.add(val)
                else:
                    missing.append((f, q))
            elif kind == "ext":
                ext_used[val].add(f)
    graph[f] = deps


def reach(entries):
    seen = set()
    stack = [e for e in entries if e in FILESET]
    while stack:
        cur = stack.pop()
        if cur in seen:
            continue
        seen.add(cur)
        stack.extend(graph.get(cur, ()))
    return seen


def rel(p):
    return os.path.relpath(p, ROOT)


main = os.path.join(LIB, "main.dart")
other_mains = [f for f in FILES if f.endswith("_main.dart") and f != main]
generated = {f for f in FILES if os.sep + "l10n" + os.sep in f}   # gen_l10n output

app = reach([main] + sorted(generated))
extra = reach(other_mains) - app
dead = [f for f in FILES if f not in app and f not in extra]

lines = []
w = lines.append
w("TEXO dead-code report")
w("=" * 60)
w(f"package:               {PKG or '?'}")
w(f"dart files in lib/:    {len(FILES)}")
w(f"reachable from main:   {len(app)}")
w(f"only test/preview app: {len(extra)}   ({', '.join(rel(m) for m in other_mains) or '-'})")
w(f"DEAD (unreachable):    {len(dead)}")
if not os.path.exists(main):
    w("WARNING: lib/main.dart not found, results are not reliable")
w("")

by_dir = defaultdict(list)
for f in dead:
    parts = rel(f).split(os.sep)
    key = os.sep.join(parts[:3]) if parts[1] == "features" and len(parts) > 3 else os.sep.join(parts[:2])
    by_dir[key].append(f)
w("Dead files by folder")
w("-" * 60)
for key in sorted(by_dir, key=lambda k: -len(by_dir[k])):
    loc = sum(read(f).count("\n") for f in by_dir[key])
    w(f"{len(by_dir[key]):4d} files  {loc:6d} lines   {key}")
w("")

w("Referenced files that DO NOT EXIST (what is missing)")
w("-" * 60)
real_missing = defaultdict(list)
for f, uri in missing:
    real_missing[uri].append(rel(f))
if not real_missing:
    w("none")
for uri in sorted(real_missing):
    users = real_missing[uri]
    live = [u for u in users if os.path.join(ROOT, u) in app]
    tag = "  [USED BY THE APP!]" if live else ""
    w(f"{uri}{tag}\n      <- {', '.join(sorted(set(users))[:3])}{' ...' if len(set(users)) > 3 else ''}")
w("")

w("Packages imported but NOT in pubspec.yaml")
w("-" * 60)
absent = sorted(p for p in ext_used if p not in DECLARED and p not in ("flutter", "flutter_test", "flutter_gen"))
if not absent:
    w("none")
for p in absent:
    users = sorted(rel(u) for u in ext_used[p])
    w(f"{p}\n      <- {', '.join(users[:3])}{' ...' if len(users) > 3 else ''}")
w("")

w("Full list of dead files")
w("-" * 60)
for f in dead:
    w(rel(f))

text = "\n".join(lines)
print("\n".join(lines[:60 + len(by_dir) + len(real_missing) * 2 + len(absent) * 2]))
if REPORT:
    with open(REPORT, "w", encoding="utf-8") as fh:
        fh.write(text + "\n")
    print(f"\nFull report written to: {REPORT}")

# ---------------------------------------------------------------- quarantine
if _args.quarantine:
    prefixes = [("lib/" + p.strip().strip("/") + "/") for p in _args.quarantine.split(",") if p.strip()]
    todo = [f for f in dead if any(rel(f).replace(os.sep, "/").startswith(pre) for pre in prefixes)]
    print(f"\nQuarantine: {len(todo)} dead files match {', '.join(prefixes)}")
    if not _args.yes:
        for f in todo[:25]:
            print("  would move:", rel(f))
        if len(todo) > 25:
            print(f"  ... and {len(todo) - 25} more")
        print("Nothing moved. Add --yes to move them to archive/ (git mv).")
    else:
        moved = 0
        for f in todo:
            dest = os.path.join(ROOT, "archive", rel(f))
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            r = subprocess.run(["git", "mv", f, dest], cwd=ROOT, capture_output=True)
            if r.returncode != 0:
                shutil.move(f, dest)
            moved += 1
        print(f"Moved {moved} files to archive/. Undo with: git mv archive/lib/... lib/...")
