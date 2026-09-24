/// endpoint_validator.dart
/// AURA Assistant – R6-D: HTTPS Endpoint Validation
///
/// Shared validation utility for AI provider base URLs.
/// Enforces HTTPS-only, rejects http/ftp/malformed URLs.
/// Does NOT rewrite URLs. Does NOT restrict to specific provider domains.
/// Does NOT add localhost HTTP bypass.
///
/// Uses project Result/Failure architecture for validation failures.
library;

import 'package:texo/core/errors/result.dart';
import 'package:texo/features/security/domain/models/security_failure.dart';

/// Validates that an AI provider base URL meets security requirements.
///
/// Requirements:
/// - Must be a valid URI (parseable by Uri.parse)
/// - Must use HTTPS scheme
/// - Must have a host
/// - Must NOT contain userinfo (embedded credentials)
///
/// Does NOT:
/// - Restrict to specific provider domains
/// - Rewrite http:// to https://
/// - Add localhost HTTP bypass
///
/// **Note:** localhost and 127.0.0.1 over plain HTTP are explicitly
/// NOT supported, even for development. Use an HTTPS proxy or
/// a local TLS-terminating reverse proxy if you need to test
/// against a local endpoint.
class EndpointValidator {
  EndpointValidator._();

  /// Strips common copy-paste artifacts from a pasted URL:
  /// - Markdown link syntax: `[https://x.com](https://x.com)` -> `https://x.com`
  /// - Surrounding brackets/parens/angle brackets: `[https://x.com]` -> `https://x.com`
  /// - Surrounding straight/curly quotes
  /// - Trailing punctuation accidentally copied along with the URL
  ///
  /// This is a defensive pre-processing step so that pasted text from
  /// chat apps or documents doesn't get rejected as an "invalid URL"
  /// when the actual URL inside it is perfectly valid.
  static String _sanitize(String raw) {
    var s = raw.trim();

    // Markdown link: [label](url) or [url](url) -> extract the url in parens.
    final markdownLink = RegExp(r'^\[([^\]]*)\]\(([^)]+)\)$');
    final mdMatch = markdownLink.firstMatch(s);
    if (mdMatch != null) {
      s = mdMatch.group(2)!.trim();
    }

    // Strip a single layer of wrapping brackets/parens/angle brackets/quotes.
    const wrappers = [
      ['[', ']'],
      ['(', ')'],
      ['<', '>'],
      ['"', '"'],
      ["'", "'"],
    ];
    for (final pair in wrappers) {
      if (s.length >= 2 && s.startsWith(pair[0]) && s.endsWith(pair[1])) {
        s = s.substring(1, s.length - 1).trim();
      }
    }

    // If, after unwrapping, there's still a dangling markdown remnant like
    // "https://x.com](https://x.com" (mismatched braces), fall back to
    // extracting the first well-formed https:// token found in the string.
    if (s.contains('[') || s.contains(']') || s.contains('(') || s.contains(')')) {
      final urlMatch = RegExp(r'https?://[^\s\[\]()<>"' r"']+").firstMatch(s);
      if (urlMatch != null) {
        s = urlMatch.group(0)!;
      }
    }

    return s.trim();
  }

  /// Validates [url] as an acceptable AI endpoint base URL.
  ///
  /// Returns [Result.success] with the validated URL string,
  /// or [Result.failure] with a [SecurityFailure] explaining the problem.
  static Result<String, SecurityFailure> validate(String url) {
    // ─── Empty / whitespace ──────────────────────────────────
    final trimmed = _sanitize(url);
    if (trimmed.isEmpty) {
      return SecurityFailure.providerPrivacyViolation(
        action: 'setBaseUrl',
        verdictReason: 'Base URL must not be empty.',
      ).asFailure<String>();
    }

    // ─── Parse URI ───────────────────────────────────────────
    Uri uri;
    try {
      uri = Uri.parse(trimmed);
    } catch (e) {
      return SecurityFailure.providerPrivacyViolation(
        action: 'setBaseUrl',
        verdictReason: 'Invalid URL format. Could not parse: $trimmed',
      ).asFailure<String>();
    }

    // ─── HTTPS-only ───────────────────────────────────────────
    if (uri.scheme.toLowerCase() != 'https') {
      return SecurityFailure.providerPrivacyViolation(
        action: 'setBaseUrl',
        verdictReason:
            'Insecure scheme "${uri.scheme}" rejected. '
            'Only HTTPS endpoints are allowed.',
      ).asFailure<String>();
    }

    // ─── Must have a host ────────────────────────────────────
    if (uri.host.isEmpty) {
      return SecurityFailure.providerPrivacyViolation(
        action: 'setBaseUrl',
        verdictReason: 'URL must include a host. Got: $trimmed',
      ).asFailure<String>();
    }

    // ─── No embedded credentials (userinfo) ──────────────────
    if (uri.userInfo.isNotEmpty) {
      return SecurityFailure.providerPrivacyViolation(
        action: 'setBaseUrl',
        verdictReason:
            'URL must not contain embedded credentials (userinfo).',
      ).asFailure<String>();
    }

    return Result.success(trimmed);
  }

  /// Normalizes a base URL for safe path concatenation.
  ///
  /// Strips trailing slash from [baseUrl] so that
  /// `$normalizedBaseUrl/chat/completions` never produces a double slash.
  ///
  /// This does NOT validate the URL — use [validate] first.
  static String normalizeTrailingSlash(String baseUrl) {
    final trimmed = baseUrl.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }
}
