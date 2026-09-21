#!/usr/bin/env python3
"""
Patch script: robust Gemini base-URL handling.

Run this from the repo root:
    python3 patch_gemini_baseurl.py

It applies 8 targeted, exact-match text replacements across:
  - lib/core/ai/gemini_provider.dart
  - lib/core/ai/ai_connection_storage.dart
  - lib/core/ai/provider_registry.dart
  - lib/presentation/widgets/api_key_settings_section.dart

If any replacement doesn't find exactly one match, the script stops and
prints which one failed (so nothing is left half-patched) instead of
silently applying a broken subset.
"""

import sys


def patch(path, old, new, count=1):
    with open(path, encoding="utf-8") as f:
        c = f.read()
    n = c.count(old)
    if n != count:
        print(f"FAILED: {path}: expected {count} match(es), found {n}")
        print("---- looking for ----")
        print(old)
        sys.exit(1)
    c = c.replace(old, new)
    with open(path, "w", encoding="utf-8") as f:
        f.write(c)
    print(f"OK: {path}")


# 1. gemini_provider.dart: robust _rootBase (scheme+host only)
patch(
    "lib/core/ai/gemini_provider.dart",
    """  static String _rootBase(String? stored) {
    final resolved = resolveBaseUrl(stored);
    return resolved
        .replaceAll(RegExp(r'/v1beta/?$', caseSensitive: false), '')
        .replaceAll(RegExp(r'/+$'), '');
  }""",
    """  static String _rootBase(String? stored) {
    final resolved = resolveBaseUrl(stored);
    // Discard ANY path/query/fragment the stored value may carry — a user
    // may paste a full endpoint like ".../v1beta/models" by mistake, or an
    // old/corrupted save may leave extra segments — and rebuild from
    // scheme+host[+port] only. This guarantees buildGenerateContentUri /
    // buildListModelsUri can never produce a doubled path such as
    // ".../v1beta/models/v1beta/models".
    try {
      final uri = Uri.parse(resolved);
      if (uri.scheme.isEmpty || uri.host.isEmpty) return resolved;
      final portSuffix = uri.hasPort && uri.port != 0 ? ':${uri.port}' : '';
      return '${uri.scheme}://${uri.host}$portSuffix';
    } catch (_) {
      return resolved;
    }
  }""",
)

# 2. gemini_provider.dart: add clearBaseUrl()
patch(
    "lib/core/ai/gemini_provider.dart",
    """      },
    );
  }

  /// Converts AIMessage list to Gemini contents format.""",
    """      },
    );
  }

  /// Clears any custom Gemini base URL, reverting future requests to
  /// [kGeminiDefaultBaseUrl].
  Future<void> clearBaseUrl() async {
    await secureStorage.delete(key: 'aura_gemini_base_url');
  }

  /// Converts AIMessage list to Gemini contents format.""",
)

# 3. ai_connection_storage.dart: add clearBaseUrl(type)
patch(
    "lib/core/ai/ai_connection_storage.dart",
    """    await secureStorage.write(key: storageKey, value: url.trim());
  }

  // ─── Model ────────────────────────────────────────────────""",
    """    await secureStorage.write(key: storageKey, value: url.trim());
  }

  /// Deletes any stored base URL for the given connection type, reverting
  /// future [getBaseUrl] reads back to the built-in default.
  Future<void> clearBaseUrl([ConnectionType? type]) async {
    final connectionType = type ?? getConnectionType();
    final storageKey = connectionType == ConnectionType.gemini
        ? kGeminiBaseUrlStorageKey
        : kOpenAIBaseUrlStorageKey;
    await secureStorage.delete(key: storageKey);
  }

  // ─── Model ────────────────────────────────────────────────""",
)

# 4. provider_registry.dart: import + real default base URL for gemini preset
patch(
    "lib/core/ai/provider_registry.dart",
    "import 'connection_type.dart';",
    "import 'connection_type.dart';\nimport 'gemini_provider.dart' show kGeminiDefaultBaseUrl;",
)
patch(
    "lib/core/ai/provider_registry.dart",
    """      defaultModel: 'gemini-3.6-flash',
      defaultBaseUrl: '',""",
    """      defaultModel: 'gemini-3.6-flash',
      defaultBaseUrl: kGeminiDefaultBaseUrl,""",
)

# 5. api_key_settings_section.dart: import GeminiProvider + kGeminiDefaultBaseUrl
patch(
    "lib/presentation/widgets/api_key_settings_section.dart",
    "import '../../core/ai/gemini_provider.dart' show kDefaultGeminiChatModel;",
    "import '../../core/ai/gemini_provider.dart'\n    show kDefaultGeminiChatModel, GeminiProvider, kGeminiDefaultBaseUrl;",
)

# 6. hint text for the address field
patch(
    "lib/presentation/widgets/api_key_settings_section.dart",
    """          hint: _selectedProviderType == ConnectionType.gemini
              ? ''
              : 'https://api.openai.com/v1',""",
    """          hint: _selectedProviderType == ConnectionType.gemini
              ? kGeminiDefaultBaseUrl
              : 'https://api.openai.com/v1',""",
)

# 7. _saveConfig: validate before persisting + real reset-on-empty
patch(
    "lib/presentation/widgets/api_key_settings_section.dart",
    """      // Save base URL
      final baseUrl = _baseUrlController.text.trim();
      if (baseUrl.isNotEmpty) {
        try {
          await connectionStorage.setBaseUrl(baseUrl, _selectedProviderType);
          await provider.setBaseUrl(baseUrl);
        } catch (e) {
          if (mounted) {
            setState(() {
              _isSaving = false;
              _saveStatus = 'هەڵە، $e';
            });
          }
          return;
        }
      }""",
    """      // Save base URL. Validate FIRST via the provider (enforces HTTPS +
      // a real host) and only mirror it into AIConnectionStorage once that
      // succeeds, so an invalid URL can never reach secure storage. An
      // empty field is treated as an explicit reset back to the built-in
      // default rather than silently keeping whatever was saved before.
      final baseUrl = _baseUrlController.text.trim();
      if (baseUrl.isNotEmpty) {
        try {
          await provider.setBaseUrl(baseUrl);
          await connectionStorage.setBaseUrl(baseUrl, _selectedProviderType);
        } catch (e) {
          if (mounted) {
            setState(() {
              _isSaving = false;
              _saveStatus = 'هەڵە، $e';
            });
          }
          return;
        }
      } else {
        await connectionStorage.clearBaseUrl(_selectedProviderType);
        if (provider is GeminiProvider) {
          await provider.clearBaseUrl();
        }
      }""",
)

# 8. _testConnection: validate before persisting (same reordering)
patch(
    "lib/presentation/widgets/api_key_settings_section.dart",
    """      final baseUrl = _baseUrlController.text.trim();
      if (baseUrl.isNotEmpty) {
        await connectionStorage.setBaseUrl(baseUrl, _selectedProviderType);
        await provider.setBaseUrl(baseUrl);
      }""",
    """      final baseUrl = _baseUrlController.text.trim();
      if (baseUrl.isNotEmpty) {
        await provider.setBaseUrl(baseUrl);
        await connectionStorage.setBaseUrl(baseUrl, _selectedProviderType);
      }""",
)

print("ALL PATCHES APPLIED")
