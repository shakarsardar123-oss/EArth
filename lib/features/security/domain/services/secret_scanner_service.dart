/// secret_scanner_service.dart
/// AURA Assistant – Step 19: Security & Privacy Hardening
///
/// Domain service interface for scanning content for secrets/credentials.
/// FAIL CLOSED: if scanning fails or is ambiguous, treat content
/// as containing secrets.
library;

import 'package:aura_assistant/core/errors/result.dart';
import '../models/security_failure.dart';

/// A detected secret in scanned content.
class DetectedSecret {
  /// The category of the detected secret.
  final SensitiveDataCategory category;

  /// Start position of the match (redacted from output).
  final int startIndex;

  /// End position of the match (redacted from output).
  final int endIndex;

  /// Confidence score 0.0–1.0. FAIL CLOSED: low confidence → still reported.
  final double confidence;

  /// The pattern name that matched.
  final String patternName;

  /// Whether the match is considered ambiguous — FAIL CLOSED: still flagged.
  final bool isAmbiguous;

  const DetectedSecret({
    required this.category,
    required this.startIndex,
    required this.endIndex,
    required this.confidence,
    required this.patternName,
    this.isAmbiguous = false,
  });

  /// Whether this detection is high-confidence (>= 0.7).
  bool get isHighConfidence => confidence >= 0.7;

  /// Whether this detection should block the action.
  /// FAIL CLOSED: always returns true — even ambiguous detections block.
  bool get shouldBlock => true;

  @override
  String toString() =>
      'DetectedSecret(category: \${category.name}, confidence: \$confidence, '
      'pattern: \$patternName, ambiguous: \$isAmbiguous)';
}

/// Result of scanning content for secrets.
class SecretScanResult {
  /// Whether any secrets were detected.
  final bool hasSecrets;

  /// The list of detected secrets (redacted metadata only).
  final List<DetectedSecret> detectedSecrets;

  /// The redacted version of the content (all secrets replaced).
  final String redactedContent;

  /// Whether the scan itself was inconclusive — FAIL CLOSED: treat as has secrets.
  final bool isInconclusive;

  const SecretScanResult({
    required this.hasSecrets,
    this.detectedSecrets = const [],
    this.redactedContent = '',
    this.isInconclusive = false,
  });

  /// FAIL CLOSED: if scan is inconclusive, treat as if secrets found.
  bool get shouldBlockContent => hasSecrets || isInconclusive;

  @override
  String toString() =>
      'SecretScanResult(secrets: \$hasSecrets, count: \${detectedSecrets.length}, '
      'inconclusive: \$isInconclusive)';
}

/// Abstract domain service for scanning content for secrets/credentials.
///
/// Implementations MUST:
/// - Over-detect (false positives preferred over false negatives).
/// - FAIL CLOSED on scan errors → treat content as containing secrets.
/// - Never output raw matched secrets — only redacted metadata.
abstract class SecretScannerService {
  /// Scan [content] for secrets/credentials.
  ///
  /// Returns [SecretScanResult] with redacted content and detections.
  /// On error, returns [SecurityFailure] with [SecurityFailurePhase.secretScanning].
  Future<SecurityResult<SecretScanResult>> scanContent(String content);

  /// Check if [content] contains any secrets (quick boolean check).
  ///
  /// FAIL CLOSED: on error, returns true (secrets assumed present).
  Future<bool> containsSecrets(String content);

  /// Get the list of supported secret pattern names.
  List<String> get supportedPatternNames;
}
