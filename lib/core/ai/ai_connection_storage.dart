/// ai_connection_storage.dart
/// AURA Assistant – R7-C: Secure Connection Storage Service
///
/// UPDATED: Gemini is now the default/primary provider.
/// - Default connection type: ConnectionType.gemini
/// - Default model: gemini-3.6-flash
/// - Default base URL: Gemini native API
/// - Gemini API key: FlutterSecureStorage (key: 'aura_gemini_api_key')
/// - OpenAI API key: FlutterSecureStorage (key: 'aura_openai_api_key') — preserved
/// - OpenAI base URL: FlutterSecureStorage (key: 'aura_openai_base_url') — preserved
/// - Gemini base URL: FlutterSecureStorage (key: 'aura_gemini_base_url')
/// - Model: SharedPreferences (key: 'aura_ai_model')
/// - Connection type: SharedPreferences (key: 'aura_ai_connection_type')
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_connection_config.dart';
import 'connection_type.dart';
import 'endpoint_validator.dart';
import 'provider_exception.dart';
import '../errors/result.dart';

/// SharedPreferences key for the AI model name.
const kModelStorageKey = 'aura_ai_model';

/// SharedPreferences key for the connection type index.
const kConnectionTypeStorageKey = 'aura_ai_connection_type';

/// SharedPreferences key for the "auto model selection" flag.
///
/// When `true` (the default), the app is allowed to auto-discover and
/// auto-select a compatible chat model, and to silently re-select a new
/// model if the stored one disappears server-side. When `false`, the model
/// was explicitly chosen by the user and must never be overwritten
/// automatically.
const kModelAutoStorageKey = 'aura_ai_model_auto';

/// SharedPreferences key recording who last set the model: `auto` or `user`.
/// This is a human-readable mirror of [kModelAutoStorageKey], kept for
/// diagnostics and forward compatibility.
const kModelSourceStorageKey = 'aura_ai_model_source';

/// Value stored in [kModelSourceStorageKey] when the app auto-selected.
const kModelSourceAuto = 'auto';

/// Value stored in [kModelSourceStorageKey] when the user chose the model.
const kModelSourceUser = 'user';

/// Secure storage key for the Gemini base URL.
const kGeminiBaseUrlStorageKey = 'aura_gemini_base_url';

/// Secure storage key for the OpenAI base URL (preserved for backward compat).
const kOpenAIBaseUrlStorageKey = 'aura_openai_base_url';

/// Secure storage key for the Gemini API key.
const kGeminiApiKeyStorageKey = 'aura_gemini_api_key';

/// Secure storage key for the OpenAI API key (preserved for backward compat).
const kOpenAIApiKeyStorageKey = 'aura_openai_api_key';

/// Service for persisting and reading AI connection configuration.
///
/// Manages storage for both Gemini (primary) and OpenAI (secondary) providers.
/// API key CRUD for Gemini is handled by GeminiProvider directly.
/// API key CRUD for OpenAI is handled by OpenAIProvider directly.
/// This service handles: base URL reads, model name, connection type.
class AIConnectionStorage {
  AIConnectionStorage({
    required this.secureStorage,
    required this.sharedPreferences,
  });

  final FlutterSecureStorage secureStorage;
  final SharedPreferences sharedPreferences;

  // ─── Base URL ─────────────────────────────────────────────

  /// Reads the stored base URL for the given connection type.
  /// Returns the appropriate default if nothing is stored.
  Future<String> getBaseUrl([ConnectionType? type]) async {
    final connectionType = type ?? getConnectionType();
    switch (connectionType) {
      case ConnectionType.gemini:
        final url =
            await secureStorage.read(key: kGeminiBaseUrlStorageKey);
        return url ?? kDefaultBaseUrl;
      case ConnectionType.openaiCompatible:
        final url =
            await secureStorage.read(key: kOpenAIBaseUrlStorageKey);
        return url ?? kOpenAIDefaultBaseUrl;
      case ConnectionType.customOpenAI:
        final url =
            await secureStorage.read(key: kOpenAIBaseUrlStorageKey);
        return url ?? '';
    }
  }

  /// Stores a base URL for the given connection type in secure storage.
  ///
  /// Throws [AIProviderException] if validation fails.
  Future<void> setBaseUrl(String url, [ConnectionType? type]) async {
    final connectionType = type ?? getConnectionType();
    final storageKey = connectionType == ConnectionType.gemini
        ? kGeminiBaseUrlStorageKey
        : kOpenAIBaseUrlStorageKey;
    await secureStorage.write(key: storageKey, value: url.trim());
  }

  // ─── Model ────────────────────────────────────────────────

  /// Reads the stored model name from SharedPreferences.
  /// Returns [kDefaultChatModel] if nothing is stored.
  String getModel() {
    return sharedPreferences.getString(kModelStorageKey) ?? kDefaultChatModel;
  }

  /// Stores the model name in SharedPreferences.
  bool setModel(String model) {
    final trimmed = model.trim();
    if (trimmed.isEmpty) return false;
    sharedPreferences.setString(kModelStorageKey, trimmed.trim());
    return true;
  }

  /// Deletes the stored model name, reverting to the default.
  void deleteModel() {
    sharedPreferences.remove(kModelStorageKey);
  }

  // ─── Auto / user model-selection mode ─────────────────────

  /// Whether the app is allowed to auto-select / auto-recover the chat model.
  ///
  /// Defaults to `true` for fresh installs and for any config that predates
  /// this flag (so existing users keep working). Returns `false` only when a
  /// user has explicitly picked a model via [setUserSelectedModel].
  bool isModelAuto() {
    return sharedPreferences.getBool(kModelAutoStorageKey) ?? true;
  }

  /// Human-readable source of the current model: `auto` or `user`.
  String getModelSource() {
    final stored = sharedPreferences.getString(kModelSourceStorageKey);
    if (stored == kModelSourceUser) return kModelSourceUser;
    if (stored == kModelSourceAuto) return kModelSourceAuto;
    // Fall back to the boolean flag for configs written before the mirror
    // key existed.
    return isModelAuto() ? kModelSourceAuto : kModelSourceUser;
  }

  /// Persists a model that was chosen automatically by discovery.
  ///
  /// Marks the selection as `auto` so future auto-recovery is permitted.
  /// Returns `false` (and writes nothing) when [model] is blank.
  Future<bool> setAutoSelectedModel(String model) async {
    final trimmed = model.trim();
    if (trimmed.isEmpty) return false;
    await sharedPreferences.setString(kModelStorageKey, trimmed);
    await sharedPreferences.setBool(kModelAutoStorageKey, true);
    await sharedPreferences.setString(
      kModelSourceStorageKey,
      kModelSourceAuto,
    );
    return true;
  }

  /// Persists a model that was explicitly chosen by the user.
  ///
  /// Marks the selection as `user` so it is never overwritten by
  /// auto-recovery. Returns `false` (and writes nothing) when [model] is
  /// blank.
  Future<bool> setUserSelectedModel(String model) async {
    final trimmed = model.trim();
    if (trimmed.isEmpty) return false;
    await sharedPreferences.setString(kModelStorageKey, trimmed);
    await sharedPreferences.setBool(kModelAutoStorageKey, false);
    await sharedPreferences.setString(
      kModelSourceStorageKey,
      kModelSourceUser,
    );
    return true;
  }

  // ─── Legacy default model migration ───────────────────────

  /// Gemini chat models that this project historically shipped as the
  /// *automatic default*. Only these legacy defaults are eligible for
  /// migration to [kDefaultChatModel].
  ///
  /// IMPORTANT: models a user could explicitly pick (e.g. gemini-1.5-pro,
  /// gemini-1.0-pro) are deliberately NOT listed here, so a user's custom
  /// Gemini model choice is never overwritten.
  static const Set<String> kLegacyGeminiDefaultModels = {
    'gemini-1.5-flash',
  };

  /// Safely migrates a legacy *default* Gemini chat model to the current
  /// [kDefaultChatModel] (gemini-3.6-flash).
  ///
  /// Guarantees (fail-safe, idempotent):
  /// - Only runs when the active connection is [ConnectionType.gemini].
  ///   OpenAI / custom-OpenAI connections are never touched.
  /// - Only migrates when the stored model is one of
  ///   [kLegacyGeminiDefaultModels] (i.e. a value the app auto-assigned).
  ///   A user-chosen custom Gemini model is left untouched.
  /// - No-op when nothing is stored (getModel already returns the new
  ///   default) or when the stored model already equals the current default.
  /// - Running it repeatedly performs at most one write; subsequent calls
  ///   are no-ops.
  ///
  /// Returns `true` only when a migration write actually occurred.
  Future<bool> migrateLegacyGeminiDefaultModel() async {
    // Never touch non-Gemini providers.
    if (getConnectionType() != ConnectionType.gemini) return false;

    final stored = sharedPreferences.getString(kModelStorageKey);
    // Nothing explicitly stored → getModel() already yields the new default.
    if (stored == null) return false;

    final trimmed = stored.trim();
    // Already on the current default → idempotent no-op.
    if (trimmed == kDefaultChatModel) return false;
    // Only migrate known legacy *defaults*, never user-chosen models.
    if (!kLegacyGeminiDefaultModels.contains(trimmed)) return false;

    sharedPreferences.setString(kModelStorageKey, kDefaultChatModel);
    return true;
  }

  // ─── Connection Type ─────────────────────────────────────

  /// Reads the stored connection type from SharedPreferences.
  /// Returns [ConnectionType.gemini] if nothing is stored
  /// or if the stored value is invalid.
  ConnectionType getConnectionType() {
    final index = sharedPreferences.getInt(kConnectionTypeStorageKey);
    if (index != null &&
        index >= 0 &&
        index < ConnectionType.values.length) {
      return ConnectionType.values[index];
    }
    // Default is now Gemini
    return ConnectionType.gemini;
  }

  /// Stores the connection type in SharedPreferences.
  void setConnectionType(ConnectionType type) {
    sharedPreferences.setInt(kConnectionTypeStorageKey, type.index);
  }

  // ─── Full Config ─────────────────────────────────────────

  /// Reads the full connection config from storage.
  Future<AIConnectionConfig> getConfig() async {
    return AIConnectionConfig(
      connectionType: getConnectionType(),
      baseUrl: await getBaseUrl(),
      model: getModel(),
    );
  }

  /// Saves the full connection config to storage.
  ///
  /// Base URL is validated before saving.
  /// API keys are NOT part of this config — use provider methods.
  Future<bool> saveConfig(AIConnectionConfig config) async {
    setConnectionType(config.connectionType);
    await setBaseUrl(config.baseUrl, config.connectionType);
    return setModel(config.model);
  }
}
