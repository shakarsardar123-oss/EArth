/// provider_privacy_service.dart
/// AURA Assistant – Step 19: Security & Privacy Hardening
///
/// Application service for API provider privacy.
/// Ensures no sensitive data is sent to external API providers.
///
/// FAIL CLOSED: if privacy check fails, content is NOT sent.
library;

import 'package:aura_assistant/core/errors/result.dart';
import '../domain/models/security_config.dart';
import '../domain/models/security_failure.dart';
import '../domain/models/security_verdict.dart';

/// Privacy level for a specific API provider.
class ProviderPrivacyProfile {
  /// The provider identifier (e.g., 'openai', 'google', 'anthropic').
  final String providerId;

  /// Human-readable provider name.
  final String displayName;

  /// The privacy mode for this provider.
  final ProviderPrivacyMode privacyMode;

  /// Additional data categories to strip for this provider.
  final List<SensitiveDataCategory> additionalStripCategories;

  /// Whether this provider supports on-device processing.
  final bool supportsOnDevice;

  /// The provider's data retention policy (redacted description).
  final String? dataRetentionPolicy;

  const ProviderPrivacyProfile({
    required this.providerId,
    required this.displayName,
    this.privacyMode = ProviderPrivacyMode.stripSensitiveOnly,
    this.additionalStripCategories = const [],
    this.supportsOnDevice = false,
    this.dataRetentionPolicy,
  });

  /// All categories to strip (base + additional).
  List<SensitiveDataCategory> get allStripCategories =>
      [...additionalStripCategories];
}

/// Result of a provider privacy check.
class ProviderPrivacyResult {
  /// Whether the content is safe to send.
  final bool isSafeToSend;

  /// The redacted version of the content (safe to send).
  final String redactedContent;

  /// Categories that were stripped.
  final List<SensitiveDataCategory> strippedCategories;

  /// The provider the content was prepared for.
  final String providerId;

  /// Whether the content was over-redacted (FAIL CLOSED fallback).
  final bool wasOverRedacted;

  const ProviderPrivacyResult({
    required this.isSafeToSend,
    this.redactedContent = '',
    this.strippedCategories = const [],
    required this.providerId,
    this.wasOverRedacted = false,
  });

  /// FAIL CLOSED: if over-redacted, content is technically safe but degraded.
  bool get isContentDegraded => wasOverRedacted;

  @override
  String toString() =>
      'ProviderPrivacyResult(safe: \$isSafeToSend, provider: \$providerId, '
      'stripped: \${strippedCategories.length}, degraded: \$isContentDegraded)';
}

/// Abstract application service for provider privacy.
abstract class ProviderPrivacyService {
  /// Prepare content for sending to a specific [providerId].
  ///
  /// Strips PII according to the provider's privacy profile.
  /// Returns [ProviderPrivacyResult] with redacted content.
  /// FAIL CLOSED: if preparation fails, content is NOT sent.
  Future<SecurityResult<ProviderPrivacyResult>> prepareContent(
    String content,
    String providerId,
  );

  /// Check if content is safe to send to a provider.
  Future<SecurityResult<SecurityVerdict>> checkContent(
    String content,
    String providerId,
  );

  /// Register a provider privacy profile.
  bool registerProvider(ProviderPrivacyProfile profile);

  /// Get a provider's privacy profile.
  ProviderPrivacyProfile? getProviderProfile(String providerId);

  /// Get all registered provider IDs.
  List<String> get registeredProviderIds;

  /// The current global provider privacy mode.
  ProviderPrivacyMode get currentMode;
}
