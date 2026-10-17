"""Switches lib/main.dart from the old MaterialApp/MainShell to the new TEXO UI.
Run from the project root:  python3 tools/patch_main.py"""
import sys

P = "lib/main.dart"
s = open(P, encoding="utf-8").read()
if "TexoUiHost" in s:
    print("already patched")
    sys.exit(0)

imp = "import 'l10n/app_localizations.dart';\n"
if s.count(imp) != 1:
    print("FAIL: import anchor count =", s.count(imp))
    sys.exit(1)

start_marker = "    return MaterialApp("
end_marker = "      home: const MainShell(),\n    );"
if s.count(start_marker) != 1 or s.count(end_marker) != 1:
    print("FAIL: build() anchors", s.count(start_marker), s.count(end_marker))
    sys.exit(1)
a = s.index(start_marker)
b = s.index(end_marker) + len(end_marker)
if a > b:
    print("FAIL: anchors out of order")
    sys.exit(1)

new_build = """    return TexoUiHost(
      navigatorKey: navigatorKey,
      initialLang: locale.code,
      onLangChanged: (String lang) => ref
          .read(overriddenLocaleProvider.notifier)
          .setLocale(lang == 'en' ? AuraLocale.en : AuraLocale.ku),
    );"""
s = s[:a] + new_build + s[b:]
s = s.replace(imp, imp + "import 'bridge/texo_ui_host.dart';\n")
s = s.replace("import 'presentation/screens/main_shell.dart';\n", "")
open(P, "w", encoding="utf-8").write(s)
print("OK")
