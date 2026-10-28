#!/usr/bin/env python3
"""Static wiring audit for a Flutter project (run from the project root).

Answers: which code is actually reachable from lib/main.dart, which providers
would throw at runtime, which features run on stubs, which agent tools are
never constructed, and which native methods Dart calls that Kotlin lacks.

NOTE: this is static analysis. "wired" means "referenced", not "works".
"""
import collections
import os
import re
import sys

if not os.path.exists('pubspec.yaml') or not os.path.isdir('lib'):
    sys.exit('Run this from the Flutter project root (e.g. ~/EArth).')


def read(p):
    try:
        with open(p, encoding='utf-8', errors='replace') as f:
            return f.read()
    except Exception:
        return ''


m = re.search(r'^name:\s*([A-Za-z0-9_]+)', read('pubspec.yaml'), re.M)
PKG = m.group(1) if m else ''

dart_files = []
for dp, _dn, fns in os.walk('lib'):
    for f in fns:
        if f.endswith('.dart'):
            dart_files.append(os.path.normpath(os.path.join(dp, f)))
dart_set = set(dart_files)
text = {p: read(p) for p in dart_files}

DIR_RE = re.compile(r'^[ \t]*(import|export|part)\b(?![ \t]+of\b)([^;]*);', re.M)
STR_RE = re.compile(r'''['"]([^'"]+\.dart)['"]''')


def resolve(src, target):
    if target.startswith('dart:'):
        return None
    if target.startswith('package:'):
        pk, _, path = target[len('package:'):].partition('/')
        return os.path.normpath(os.path.join('lib', path)) if pk == PKG else None
    return os.path.normpath(os.path.join(os.path.dirname(src), target))


edges = {}
for p, t in text.items():
    outs = set()
    for mm in DIR_RE.finditer(t):
        for s in STR_RE.findall(mm.group(2)):
            r = resolve(p, s)
            if r in dart_set:
                outs.add(r)
    edges[p] = outs

MAIN = os.path.normpath('lib/main.dart')
if MAIN not in dart_set:
    sys.exit('lib/main.dart not found')

reach = {MAIN}
stack = [MAIN]
while stack:
    cur = stack.pop()
    for n in edges.get(cur, ()):
        if n not in reach:
            reach.add(n)
            stack.append(n)


def group(p):
    parts = p.split(os.sep)
    if len(parts) >= 3 and parts[1] in (
            'features', 'core', 'services', 'domain', 'data', 'presentation'):
        return parts[1] + '/' + (parts[2] if len(parts) > 3 else '(root)')
    return parts[1] if len(parts) > 2 else '(lib root)'


G = collections.defaultdict(lambda: [0, 0])
for p in dart_files:
    g = group(p)
    G[g][0] += 1
    if p in reach:
        G[g][1] += 1

# external importers per group (reachable files outside the group importing it)
ext = collections.defaultdict(set)
for p in reach:
    for n in edges.get(p, ()):
        if group(n) != group(p) and n in reach:
            ext[group(n)].add(p)

full = []
out = []


def both(line=''):
    out.append(line)
    full.append(line)


def only_full(line=''):
    full.append(line)


def capped(items, n=25, fmt=lambda x: x):
    for it in items[:n]:
        both('   ' + fmt(it))
    if len(items) > n:
        both('   ... +%d more (see audit_full.txt)' % (len(items) - n))
        for it in items[n:]:
            only_full('   ' + fmt(it))


total = len(dart_files)
both('=== 1. REACHABILITY FROM lib/main.dart')
both('lib dart files: %d | reachable: %d | NOT reachable: %d' %
     (total, len(reach), total - len(reach)))
both('')
dead = sorted([(g, v) for g, v in G.items() if v[1] == 0], key=lambda x: -x[1][0])
part = sorted([(g, v) for g, v in G.items() if 0 < v[1] < v[0]],
              key=lambda x: x[1][1] / x[1][0])
whole = sorted([(g, v) for g, v in G.items() if v[1] == v[0]])
both('--- groups with ZERO reachable files (never part of the app): %d' % len(dead))
capped(dead, 40, lambda x: '%-40s %d files' % (x[0], x[1][0]))
both('--- groups only PARTLY reachable (reachable/total, outside importers): %d' % len(part))
capped(part, 40, lambda x: '%-40s %d/%d  importers:%d' % (
    x[0], x[1][1], x[1][0], len(ext.get(x[0], ()))))
both('--- groups fully reachable: %d' % len(whole))
capped(whole, 60, lambda x: '%-40s %d files  importers:%d' % (
    x[0], x[1][0], len(ext.get(x[0], ()))))
only_full('')
only_full('--- every unreachable file:')
for p in sorted(dart_set - reach):
    only_full('   ' + p)

# ---- providers that throw if nobody overrides them
both('')
both('=== 2. PROVIDERS THAT THROW UnimplementedError (must be overridden)')
PROV_RE = re.compile(
    r'final\s+(\w+)\s*=\s*(?:Provider|StateProvider|FutureProvider|StreamProvider|'
    r'StateNotifierProvider|NotifierProvider|AsyncNotifierProvider|ChangeNotifierProvider)\b'
    r'[^;]*?(?:\{\s*|=>\s*)throw\s+UnimplementedError', re.S)
bad_used, bad_unused, ok_over = [], [], []
for p, t in text.items():
    for mm in PROV_RE.finditer(t):
        name = mm.group(1)
        ov = re.compile(r'\b' + re.escape(name) + r'\s*\.\s*override\w*\s*\(')
        overridden = any(ov.search(text[q]) for q in reach)
        word = re.compile(r'\b' + re.escape(name) + r'\b')
        users = [q for q in reach if q != p and word.search(text[q])]
        if overridden:
            ok_over.append((name, p))
        elif users and p in reach:
            bad_used.append((name, p, users))
        else:
            bad_unused.append((name, p))
both('overridden OK: %d' % len(ok_over))
both('NOT overridden AND used by reachable code (WILL THROW at runtime): %d' % len(bad_used))
capped(bad_used, 30, lambda x: '%s  (%s)  used in: %s' % (
    x[0], x[1], ', '.join(sorted(os.path.basename(u) for u in x[2])[:3])))
both('NOT overridden and unused (dead): %d' % len(bad_unused))
for name, p in bad_unused:
    only_full('   %s (%s)' % (name, p))

# ---- stubs
both('')
both('=== 3. STUB / FAKE CLASSES THAT THE REACHABLE APP CONSTRUCTS (feature runs on a stub)')
STUB_RE = re.compile(
    r'^[ \t]*class\s+(Stub\w+|\w+Stub|\w*Noop\w*|Fake\w+|Mock\w+)\b', re.M)
stub_used = []
for p, t in text.items():
    for mm in STUB_RE.finditer(t):
        name = mm.group(1)
        pat = re.compile(r'\b' + re.escape(name) + r'\s*\(')
        users = [q for q in reach if q != p and pat.search(text[q])]
        if users:
            stub_used.append((name, p, users))
both('count: %d' % len(stub_used))
capped(stub_used, 30, lambda x: '%s  used in: %s' % (
    x[0], ', '.join(sorted(os.path.basename(u) for u in x[2])[:3])))

# ---- agent tools
both('')
both('=== 4. AGENT TOOLS (classes extending Tool)')
TOOL_RE = re.compile(r'^[ \t]*class\s+(\w+)\s+extends\s+Tool\b', re.M)
used_tools, unused_tools = [], []
for p, t in text.items():
    for mm in TOOL_RE.finditer(t):
        name = mm.group(1)
        pat = re.compile(r'\b' + re.escape(name) + r'\s*\(')
        users = [q for q in reach if q != p and pat.search(text[q])]
        (used_tools if users else unused_tools).append((name, p))
both('constructed by reachable code: %d' % len(used_tools))
capped(sorted(used_tools), 60, lambda x: x[0])
both('NEVER constructed (the agent can not use these): %d' % len(unused_tools))
capped(sorted(unused_tools), 60, lambda x: '%s  (%s)' % (x[0], x[1]))

# ---- native bridge
both('')
both('=== 5. DART -> NATIVE: channels and methods missing in Kotlin')
kt = ''
for dp, _dn, fns in os.walk(os.path.join('android', 'app', 'src', 'main')):
    for f in fns:
        if f.endswith('.kt') or f.endswith('.java'):
            kt += read(os.path.join(dp, f)) + '\n'
kt_strings = set(re.findall(r'"([A-Za-z0-9_./$:-]+)"', kt))
dart_channels, dart_methods = {}, {}
for p in reach:
    t = text[p]
    for c in re.findall(r'''['"](com\.texo\.[A-Za-z0-9_./]+)['"]''', t):
        dart_channels.setdefault(c, p)
    for mth in re.findall(r'''invokeMethod(?:<[^>]*>)?\(\s*['"](\w+)['"]''', t):
        dart_methods.setdefault(mth, p)
    if 'MethodNames' in t:
        for mth in re.findall(r'''static\s+const\s+String\s+\w+\s*=\s*['"](\w+)['"]''', t):
            dart_methods.setdefault(mth, p)
miss_ch = sorted(c for c in dart_channels if c not in kt_strings and c not in kt)
miss_m = sorted(m_ for m_ in dart_methods if m_ not in kt_strings)
both('Dart channels with no matching string in Kotlin: %d' % len(miss_ch))
capped(miss_ch, 30, lambda c: '%s  (%s)' % (c, dart_channels[c]))
both('Dart method names with no matching string in Kotlin: %d  (native->Dart event names may appear here too)' % len(miss_m))
capped(miss_m, 40, lambda m_: '%s  (%s)' % (m_, dart_methods[m_]))

both('')
both('=== NOTE: static analysis only. "wired" = referenced from the app, not "works".')
with open('audit_full.txt', 'w', encoding='utf-8') as f:
    f.write('\n'.join(full) + '\n')
print('\n'.join(out))
print('\n(full details written to audit_full.txt)')
