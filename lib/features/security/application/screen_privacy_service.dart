/// screen_privacy_service.dart
/// AURA Assistant – Step 19: Security & Privacy Hardening
///
/// Application service for screen/vision privacy.
/// Protects on-screen content from unauthorized access or exfiltration.
///
/// FAIL CLOSED: if privacy check fails, screen content is protected.
library;

import 'package:aura_assistant/core/errors/result.dart';
import '../domain/models/security_config.dart';
import '../domain/models/security_failure.dart';

/// The type of screen content being checked.
enum ScreenContentType {
  /// Full screen capture.
  fullCapture,

  /// Partial screen region.
  partialRegion,

  /// OCR text extracted from screen.
  ocrText,

  /// App content visible on screen.
  appContent,

  /// Unknown type — FAIL CLOSED: treated as full capture.
  unknown,
}

/// Metadata about screen content.
class ScreenContentMetadata {
  /// The type of screen content.
  final ScreenContentType contentType;

  /// The app package that owns the content (if known).
  final String? owningAppPackage;

  /// Whether the content contains text.
  final bool containsText;

  /// Whether the content contains images.
  final bool containsImages;

  /// Sensitive data categories detected in the content.
  final List<SensitiveDataCategory> detectedCategories;

  const ScreenContentMetadata({
    this.contentType = ScreenContentType.unknown,
    this.owningAppPackage,
    this.containsText = false,
    this.containsImages = false,
    this.detectedCategories = const [],
  });

  /// Whether the content appears to contain sensitive data.
  bool get appearsSensitive => detectedCategories.isNotEmpty;

  /// FAIL CLOSED: unknown type treated as full capture.
  ScreenContentType get effectiveContentType =>
      contentType == ScreenContentType.unknown
          ? ScreenContentType.fullCapture
          : contentType;
}

/// Result of a screen privacy check.
class ScreenPrivacyResult {
  /// Whether the screen content is allowed to be accessed.
  final bool isAllowed;

  /// The redacted version of the screen content (if applicable).
  final String? redactedContent;

  /// The reason for denial (if blocked).
  final String? denialReason;

  /// The sensitive categories detected.
  final List<SensitiveDataCategory> sensitiveCategories;

  /// Whether screen capture protection was applied.
  final bool captureProtectionApplied;

  const ScreenPrivacyResult({
    required this.isAllowed,
    this.redactedContent,
    this.denialReason,
    this.sensitiveCategories = const [],
    this.captureProtectionApplied = false,
  });

  @override
  String toString() =>
      'ScreenPrivacyResult(allowed: \$isAllowed, categories: \${sensitiveCategories.length}, '
      'captureProtected: \$captureProtectionApplied)';
}

/// Abstract application service for screen privacy.
abstract class ScreenPrivacyService {
  /// Check if screen content can be accessed.
  Future<SecurityResult<ScreenPrivacyResult>> checkScreenAccess(
    ScreenContentMetadata metadata, {
    String requester = 'unknown',
  });

  /// Redact text extracted from screen (e.g., OCR output).
  Future<SecurityResult<String>> redactScreenText(String ocrText);

  /// Check if a sensitive app is currently on screen.
  bool isSensitiveAppOnScreen(String appPackage);

  /// Register a sensitive app package.
  bool registerSensitiveApp(String appPackage);

  /// Unregister a sensitive app package.
  bool unregisterSensitiveApp(String appPackage);

  /// Get all registered sensitive app packages.
  List<String> get sensitiveApps;

  /// The current screen privacy mode.
  ScreenPrivacyMode get currentMode;
}
