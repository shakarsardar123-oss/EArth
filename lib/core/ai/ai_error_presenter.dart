/// ai_error_presenter.dart
/// AURA Assistant – Phase 1: Friendly, localized AI error presentation
///
/// Turns low-level failures (structured [AIProviderException], parse
/// failures, timeouts, or an opaque error token that survived the
/// AgentEngine's string-only [AgentResult.errorMessage]) into a short,
/// human, localized message shown to normal users — never a raw
/// `AIProviderException(gemini, 401, ...)` dump.
///
/// Design notes (production-safe):
/// - Pure + deterministic. No I/O, no provider calls, no state.
/// - [categorize] classifies any [Object] into one [AIErrorCategory].
/// - [tokenFor]/[categoryFromToken] give a STABLE, machine-safe token so the
///   engine (which can only carry a `String` on [AgentResult]) can hand the
///   category to the UI layer without leaking a localized or raw string.
/// - [present] maps an error (or token) to a localized [S] string.
/// - [debugDetail] returns a developer-only detail string for logs; it is
///   never shown to end users by the UI paths.
library;

import 'package:aura_assistant/l10n/app_localizations.dart';

import 'provider_exception.dart';

/// Coarse, user-facing categories of AI failure.
enum AIErrorCategory {
  /// No API key configured at all.
  missingKey,

  /// API key present but rejected (401/403).
  auth,

  /// Rate limited (429).
  rateLimit,

  /// Configured model is gone / unsupported server-side.
  modelUnavailable,

  /// Discovery found no chat-capable model for this key.
  noCompatibleModel,

  /// Network unreachable / connection failure.
  network,

  /// Request timed out.
  timeout,

  /// Server-side error (5xx).
  server,

  /// Response blocked by a safety filter.
  blocked,

  /// Provider returned an unexpected / unparseable response.
  invalidResponse,

  /// Anything we cannot confidently classify.
  unknown,
}

/// Presents AI errors as short, friendly, localized messages.
class AIErrorPresenter {
  AIErrorPresenter._();

  /// Classifies any [error] into a single [AIErrorCategory].
  ///
  /// Accepts a structured [AIProviderException], a plain error token string
  /// previously produced by [tokenFor] (as carried on
  /// [AgentResult.errorMessage]), a [FormatException], or anything else.
  static AIErrorCategory categorize(Object? error) {
    if (error is AIErrorCategory) return error;
    if (error is AIProviderException) return _fromProviderException(error);

    if (error is String) {
      // First: is it one of our stable tokens?
      final token = categoryFromToken(error);
      if (token != null) return token;
      // Otherwise best-effort keyword sniffing on a raw message.
      return _fromRawString(error);
    }

    final typeName = error.runtimeType.toString().toLowerCase();
    if (typeName.contains('timeout')) return AIErrorCategory.timeout;
    if (typeName.contains('format')) return AIErrorCategory.invalidResponse;
    if (typeName.contains('socket') || typeName.contains('http')) {
      return AIErrorCategory.network;
    }
    if (error == null) return AIErrorCategory.unknown;
    return _fromRawString(error.toString());
  }

  static AIErrorCategory _fromProviderException(AIProviderException e) {
    final code = (e.errorCode ?? '').toUpperCase();
    if (code == 'NO_API_KEY') return AIErrorCategory.missingKey;
    if (e.isAuthError) return AIErrorCategory.auth;
    if (e.isRateLimit) return AIErrorCategory.rateLimit;
    if (e.isModelNotFound) return AIErrorCategory.modelUnavailable;
    if (code == 'RESPONSE_BLOCKED') return AIErrorCategory.blocked;
    if (code == 'INVALID_JSON' ||
        code == 'PARSE_ERROR' ||
        code == 'EMPTY_RESPONSE' ||
        code == 'NO_CANDIDATES') {
      return AIErrorCategory.invalidResponse;
    }
    if (code == 'TIMEOUT') return AIErrorCategory.timeout;
    if (e.isNetworkError) return AIErrorCategory.network;
    if (e.isServerError) return AIErrorCategory.server;
    return AIErrorCategory.unknown;
  }

  static AIErrorCategory _fromRawString(String raw) {
    final s = raw.toLowerCase();
    if (s.contains('no_api_key') || s.contains('api key not configured')) {
      return AIErrorCategory.missingKey;
    }
    if (s.contains('timed out') || s.contains('timeout')) {
      return AIErrorCategory.timeout;
    }
    if (s.contains('blocked')) return AIErrorCategory.blocked;
    if (s.contains('network error') || s.contains('socketexception')) {
      return AIErrorCategory.network;
    }
    return AIErrorCategory.unknown;
  }

  // ─── Stable machine tokens (engine ↔ UI bridge) ───────────────────

  /// Prefix marking a value as an AURA error token rather than free text.
  static const String tokenPrefix = 'aura_ai_err:';

  /// Returns a STABLE token string for [error], safe to carry across the
  /// String-only [AgentResult.errorMessage] boundary and decode later.
  static String tokenFor(Object? error) =>
      '$tokenPrefix${categorize(error).name}';

  /// Decodes a token produced by [tokenFor] back to its category, or null
  /// when [value] is not one of our tokens.
  static AIErrorCategory? categoryFromToken(String value) {
    if (!value.startsWith(tokenPrefix)) return null;
    final name = value.substring(tokenPrefix.length);
    for (final c in AIErrorCategory.values) {
      if (c.name == name) return c;
    }
    return null;
  }

  // ─── Localized presentation ─────────────────────────────────

  /// Localized, user-facing message for a category.
  static String messageForCategory(AIErrorCategory category, S l10n) {
    switch (category) {
      case AIErrorCategory.missingKey:
        return l10n.aiErrorMissingKey;
      case AIErrorCategory.auth:
        return l10n.aiErrorAuth;
      case AIErrorCategory.rateLimit:
        return l10n.aiErrorRateLimit;
      case AIErrorCategory.modelUnavailable:
        return l10n.aiErrorModelUnavailable;
      case AIErrorCategory.noCompatibleModel:
        return l10n.aiErrorNoCompatibleModel;
      case AIErrorCategory.network:
        return l10n.aiErrorNetwork;
      case AIErrorCategory.timeout:
        return l10n.aiErrorTimeout;
      case AIErrorCategory.server:
        return l10n.aiErrorServer;
      case AIErrorCategory.blocked:
        return l10n.aiErrorBlocked;
      case AIErrorCategory.invalidResponse:
        return l10n.aiErrorInvalidResponse;
      case AIErrorCategory.unknown:
        return l10n.aiErrorUnknown;
    }
  }

  /// Localized, user-facing message for any [error] (exception or token).
  static String present(Object? error, S l10n) =>
      messageForCategory(categorize(error), l10n);

  /// Developer-only detail for logs. NEVER surfaced to end users.
  static String debugDetail(Object? error) {
    if (error is AIProviderException) {
      return 'AIProviderException(provider=${error.providerId}, '
          'status=${error.statusCode}, code=${error.errorCode}): '
          '${error.message}';
    }
    return error?.toString() ?? 'null';
  }
}
