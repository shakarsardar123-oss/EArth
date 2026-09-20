#!/usr/bin/env python3
"""Generate Flutter l10n files from ARB sources."""
import json
import os

ARB_DIR = "/nfs/103520092/outputs/aura_assistant/lib/core/localization"
OUT_DIR = "/nfs/103520092/outputs/aura_assistant/.dart_tool/flutter_gen/gen_l10n"

def read_arb(path):
    with open(path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    return {k: v for k, v in data.items() if not k.startswith('@')}

ku = read_arb(os.path.join(ARB_DIR, "app_ku.arb"))
en = read_arb(os.path.join(ARB_DIR, "app_en.arb"))
all_keys = sorted(set(list(ku.keys()) + list(en.keys())))
print(f"Found {len(all_keys)} keys")

def escape_single(s):
    return s.replace("'", "''")

# Build implementation method lines
def build_impl_lines(keys, translations):
    lines = []
    for key in keys:
        val = translations.get(key, '')
        val_escaped = escape_single(val)
        lines.append(f"  @override\n  String get {key} => '{val_escaped}';")
    return lines

en_lines = build_impl_lines(all_keys, en)
ku_lines = build_impl_lines(all_keys, ku)

# Build abstract getter lines
def build_abstract_lines(keys, ku_translations):
    lines = []
    for key in keys:
        ku_val = ku_translations.get(key, '')
        ku_escaped = escape_single(ku_val)
        lines.append(
            f"  /// No description provided for @{key}.\n"
            f"  ///\n"
            f"  /// In ku, this message translates to:\n"
            f"  /// **'{ku_escaped}'**\n"
            f"  String get {key};"
        )
    return lines

abstract_lines = build_abstract_lines(all_keys, ku)

# app_localizations.dart
app_localizations_dart = (
"import 'dart:async';\n"
"\n"
"import 'package:flutter/foundation.dart';\n"
"import 'package:flutter/widgets.dart';\n"
"import 'package:flutter_localizations/flutter_localizations.dart';\n"
"import 'package:intl/intl.dart' as intl;\n"
"\n"
"import 'app_localizations_en.dart';\n"
"import 'app_localizations_ku.dart';\n"
"\n"
"// ignore_for_file: type=lint\n"
"\n"
"/// Callers can lookup localized strings with an instance of S\n"
"/// returned by `S.of(context)`.\n"
"///\n"
"/// Applications need to include `S.delegate()` in their app's\n"
"/// `localizationDelegates` list, and the locales they support in the app's\n"
"/// `supportedLocales` list. For example:\n"
"///\n"
"/// ```dart\n"
"/// import 'gen_l10n/app_localizations.dart';\n"
"///\n"
"/// return MaterialApp(\n"
"///   localizationsDelegates: S.localizationsDelegates,\n"
"///   supportedLocales: S.supportedLocales,\n"
"///   home: MyApplicationHome(),\n"
"/// );\n"
"/// ```\n"
"///\n"
"/// ## Update pubspec.yaml\n"
"///\n"
"/// Please make sure to update your pubspec.yaml to include the following\n"
"/// packages:\n"
"///\n"
"/// ```yaml\n"
"/// dependencies:\n"
"///   # Internationalization support.\n"
"///   flutter_localizations:\n"
"///     sdk: flutter\n"
"///   intl: any # Use the pinned version from flutter_localizations\n"
"///\n"
"///   # Rest of dependencies\n"
"/// ```\n"
"///\n"
"/// ## iOS Applications\n"
"///\n"
"/// iOS applications define key application metadata, including supported\n"
"/// locales, in an Info.plist file that is built into the application bundle.\n"
"/// To configure the locales supported by your app, you'll need to edit this\n"
"/// file.\n"
"///\n"
"/// First, open your project's ios/Runner.xcworkspace Xcode workspace file.\n"
"/// Then, in the Project Navigator, open the Info.plist file under the Runner\n"
"/// project folder.\n"
"///\n"
"/// Next, select the Information Property List item, select Add Item from the\n"
"/// Editor menu, then select Localizations from the pop-up menu.\n"
"///\n"
"/// Select and expand the newly-created Localizations item then, for each\n"
"/// locale your application supports, add a new item and select the locale\n"
"/// you wish to add from the pop-up menu in the Value field. This list should\n"
"/// be consistent with the languages listed in the S.supportedLocales\n"
"/// property.\n"
"abstract class S {\n"
"  S(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());\n"
"\n"
"  final String localeName;\n"
"\n"
"  static S of(BuildContext context) {\n"
"    return Localizations.of<S>(context, S)!;\n"
"  }\n"
"\n"
"  static const LocalizationsDelegate<S> delegate = _SDelegate();\n"
"\n"
"  /// A list of this localizations delegate along with the default localizations\n"
"  /// delegates.\n"
"  ///\n"
"  /// Returns a list of localizations delegates containing this delegate along with\n"
"  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,\n"
"  /// and GlobalWidgetsLocalizations.delegate.\n"
"  ///\n"
"  /// Additional delegates can be added by appending to this list in\n"
"  /// MaterialApp. This list does not have to be used at all if a custom list\n"
"  /// of delegates is preferred or required.\n"
"  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[\n"
"    delegate,\n"
"    GlobalMaterialLocalizations.delegate,\n"
"    GlobalCupertinoLocalizations.delegate,\n"
"    GlobalWidgetsLocalizations.delegate,\n"
"  ];\n"
"\n"
"  /// A list of this localizations delegate's supported locales.\n"
"  static const List<Locale> supportedLocales = <Locale>[\n"
"    Locale('en'),\n"
"    Locale('ku')\n"
"  ];\n"
"\n"
)

# Add abstract getters
app_localizations_dart += '\n'.join(abstract_lines) + '\n}\n\n'

# Add delegate and lookup
app_localizations_dart += (
"class _SDelegate extends LocalizationsDelegate<S> {\n"
"  const _SDelegate();\n"
"\n"
"  @override\n"
"  Future<S> load(Locale locale) {\n"
"    return SynchronousFuture<S>(lookupS(locale));\n"
"  }\n"
" \n"
"  @override\n"
"  bool isSupported(Locale locale) => <String>['en', 'ku'].contains(locale.languageCode);\n"
" \n"
"  @override\n"
"  bool shouldReload(_SDelegate old) => false;\n"
"}\n"
"\n"
"S lookupS(Locale locale) {\n"
"\n"
"\n"
"  // Lookup logic when only language code is specified.\n"
"  switch (locale.languageCode) {\n"
"    case 'en': return SEn();\n"
"    case 'ku': return SKu();\n"
"  }\n"
"\n"
"  throw FlutterError(\n"
"    'S.delegate failed to load unsupported locale \\$locale\". This is likely '\n"
"    'an issue with the localizations generation tool. Please file an issue '\n"
"    'on GitHub with a reproducible sample app and the gen-l10n configuration '\n"
"    'that was used.'\n"
"  );\n"
"}\n"
"\n"
)

# app_localizations_en.dart
app_localizations_en_dart = (
"import 'app_localizations.dart';\n"
"\n"
"// ignore_for_file: type=lint\n"
"\n"
"/// The translations for English (`en`).\n"
"class SEn extends S {\n"
"  SEn([String locale = 'en']) : super(locale);\n"
"\n"
)
app_localizations_en_dart += '\n'.join(en_lines) + '\n}\n'

# app_localizations_ku.dart
app_localizations_ku_dart = (
"import 'app_localizations.dart';\n"
"\n"
"// ignore_for_file: type=lint\n"
"\n"
"/// The translations for Kurdish (`ku`).\n"
"class SKu extends S {\n"
"  SKu([String locale = 'ku']) : super(locale);\n"
"\n"
)
app_localizations_ku_dart += '\n'.join(ku_lines) + '\n}\n'

# Write files
os.makedirs(OUT_DIR, exist_ok=True)

with open(os.path.join(OUT_DIR, 'app_localizations.dart'), 'w', encoding='utf-8') as f:
    f.write(app_localizations_dart)
print(f"Wrote app_localizations.dart with {len(all_keys)} getters")

with open(os.path.join(OUT_DIR, 'app_localizations_en.dart'), 'w', encoding='utf-8') as f:
    f.write(app_localizations_en_dart)
print(f"Wrote app_localizations_en.dart with {len(all_keys)} overrides")

with open(os.path.join(OUT_DIR, 'app_localizations_ku.dart'), 'w', encoding='utf-8') as f:
    f.write(app_localizations_ku_dart)
print(f"Wrote app_localizations_ku.dart with {len(all_keys)} overrides")

print("Done! All 3 l10n files generated.")
