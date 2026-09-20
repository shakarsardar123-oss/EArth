/// default_secret_scanner.dart
/// AURA Assistant – Step 19: Security & Privacy Hardening
///
/// Default infrastructure implementation of SecretScannerService.
/// Uses regex-based pattern matching for common secret formats.
///
/// FAIL CLOSED: on scan error, treats content as containing secrets.
library;

import 'package:aura_assistant/core/errors/result.dart';
import '../domain/models/security_failure.dart';
import '../domain/services/secret_scanner_service.dart';

/// Secret pattern definition.
class _SecretPattern {
  final String name;
  final SensitiveDataCategory category;
  final RegExp pattern;
  final double defaultConfidence;

  const _SecretPattern({
    required this.name,
    required this.category,
    required this.pattern,
    this.defaultConfidence = 0.9,
  });
}

/// Default regex-based secret scanner.
///
/// Over-detects by design — prefers false positives over false negatives.
class DefaultSecretScanner implements SecretScannerService {
  /// Pre-compiled secret patterns.
  static final List<_SecretPattern> _patterns = [
    _SecretPattern(
      name: 'aws_access_key',
      category: SensitiveDataCategory.apiKey,
      pattern: RegExp(r'AKIA[0-9A-Z]{16}'),
      defaultConfidence: 0.95,
    ),
    _SecretPattern(
      name: 'aws_secret_key',
      category: SensitiveDataCategory.apiKey,
      pattern: RegExp(r'aws[_\-]?secret[_\-]?access[_\-]?key\s*[=:]\s*[A-Za-z0-9/+=]{40}', caseSensitive: false),
      defaultConfidence: 0.9,
    ),
    _SecretPattern(
      name: 'github_token',
      category: SensitiveDataCategory.apiKey,
      pattern: RegExp(r'gh[ps]_[A-Za-z0-9_]{36,}'),
      defaultConfidence: 0.95,
    ),
    _SecretPattern(
      name: 'generic_api_key',
      category: SensitiveDataCategory.apiKey,
      pattern: RegExp(r'(api[_\-]?key|apikey|api[_\-]?secret)\s*[=:]\s*[A-Za-z0-9_\-]{20,}', caseSensitive: false),
      defaultConfidence: 0.7,
    ),
    _SecretPattern(
      name: 'private_key',
      category: SensitiveDataCategory.privateKey,
      pattern: RegExp(r'-----BEGIN\s+(RSA\s+)?PRIVATE\s+KEY-----'),
      defaultConfidence: 0.99,
    ),
    _SecretPattern(
      name: 'jwt_token',
      category: SensitiveDataCategory.authToken,
      pattern: RegExp(r'eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}'),
      defaultConfidence: 0.85,
    ),
    _SecretPattern(
      name: 'credit_card_visa',
      category: SensitiveDataCategory.creditCard,
      pattern: RegExp(r'4[0-9]{12}(?:[0-9]{3})?'),
      defaultConfidence: 0.8,
    ),
    _SecretPattern(
      name: 'credit_card_mastercard',
      category: SensitiveDataCategory.creditCard,
      pattern: RegExp(r'5[1-5][0-9]{14}'),
      defaultConfidence: 0.8,
    ),
    _SecretPattern(
      name: 'ssn_us',
      category: SensitiveDataCategory.nationalId,
      pattern: RegExp(r'[0-9]{3}-[0-9]{2}-[0-9]{4}'),
      defaultConfidence: 0.75,
    ),
    _SecretPattern(
      name: 'password_assignment',
      category: SensitiveDataCategory.password,
      pattern: RegExp(r'(password|passwd|pwd)\s*[=:]\s*\S+', caseSensitive: false),
      defaultConfidence: 0.85,
    ),
    _SecretPattern(
      name: 'connection_string',
      category: SensitiveDataCategory.connectionString,
      pattern: RegExp(r'(mysql|postgres|mongodb|redis)://[^\s]+', caseSensitive: false),
      defaultConfidence: 0.9,
    ),
    _SecretPattern(
      name: 'bearer_token',
      category: SensitiveDataCategory.authToken,
      pattern: RegExp(r'bearer\s+[A-Za-z0-9_\-\.]+', caseSensitive: false),
      defaultConfidence: 0.9,
    ),
    _SecretPattern(
      name: 'oauth_token',
      category: SensitiveDataCategory.authToken,
      pattern: RegExp(r'(access_token|refresh_token)\s*[=:]\s*[A-Za-z0-9_\-]{20,}', caseSensitive: false),
      defaultConfidence: 0.85,
    ),
    _SecretPattern(
      name: 'ip_address_private',
      category: SensitiveDataCategory.ipAddress,
      pattern: RegExp(r'(?:10|172\.(?:1[6-9]|2[0-9]|3[01])|192\.168)\.[0-9]{1,3}\.[0-9]{1,3}'),
      defaultConfidence: 0.6,
    ),
    _SecretPattern(
      name: 'email_address',
      category: SensitiveDataCategory.email,
      pattern: RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'),
      defaultConfidence: 0.8,
    ),
  ];

  @override
  List<String> get supportedPatternNames =>
      _patterns.map((p) => p.name).toList();

  @override
  Future<SecurityResult<SecretScanResult>> scanContent(
    String content,
  ) async {
    try {
      if (content.isEmpty) {
        return Success(SecretScanResult(
          hasSecrets: false,
          redactedContent: content,
        ));
      }

      final List<DetectedSecret> detections = [];
      final List<SensitiveDataCategory> detectedCategories = [];
      String redactedContent = content;

      // FAIL CLOSED: scan all patterns, over-detect
      for (final pattern in _patterns) {
        for (final match in pattern.pattern.allMatches(content)) {
          // Redact the matched secret
          final placeholder =
              '[REDACTED:${pattern.category.name}]';
          redactedContent = redactedContent.replaceRange(
            match.start,
            match.end,
            placeholder,
          );

          detections.add(DetectedSecret(
            category: pattern.category,
            startIndex: match.start,
            endIndex: match.end,
            confidence: pattern.defaultConfidence,
            patternName: pattern.name,
            isAmbiguous: pattern.defaultConfidence < 0.7,
          ));

          if (!detectedCategories.contains(pattern.category)) {
            detectedCategories.add(pattern.category);
          }
        }
      }

      return Success(SecretScanResult(
        hasSecrets: detections.isNotEmpty,
        detectedSecrets: detections,
        redactedContent: redactedContent,
      ));
    } catch (e) {
      // FAIL CLOSED: on error, treat content as containing secrets
      return Success(const SecretScanResult(
        hasSecrets: true,
        redactedContent: '[CONTENT BLOCKED: SCAN ERROR]',
        isInconclusive: true,
      ));
    }
  }

  @override
  Future<bool> containsSecrets(String content) async {
    try {
      for (final pattern in _patterns) {
        if (pattern.pattern.hasMatch(content)) {
          return true;
        }
      }
      return false;
    } catch (_) {
      // FAIL CLOSED: on error, assume secrets are present
      return true;
    }
  }
}
