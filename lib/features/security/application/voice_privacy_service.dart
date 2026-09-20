/// voice_privacy_service.dart
/// AURA Assistant – Step 19: Security & Privacy Hardening
///
/// Application service for voice/audio privacy.
/// Protects voice content from unauthorized access or exfiltration.
///
/// FAIL CLOSED: if privacy check fails, voice content is protected.
library;

import 'package:aura_assistant/core/errors/result.dart';
import '../domain/models/security_config.dart';
import '../domain/models/security_failure.dart';

/// The type of voice/audio content being checked.
enum VoiceContentType {
  /// Voice command from user.
  voiceCommand,

  /// Transcribed speech.
  transcription,

  /// Voice recording (raw audio).
  voiceRecording,

  /// Text-to-speech output.
  ttsOutput,

  /// Unknown — FAIL CLOSED: treated as voice recording.
  unknown,
}

/// Metadata about voice content.
class VoiceContentMetadata {
  /// The type of voice content.
  final VoiceContentType contentType;

  /// The language of the voice content (if known).
  final String? language;

  /// Whether the content contains sensitive data.
  final bool containsSensitiveData;

  /// Sensitive data categories detected.
  final List<SensitiveDataCategory> detectedCategories;

  /// Whether the content will be sent to an external service.
  final bool willBeSentExternally;

  const VoiceContentMetadata({
    this.contentType = VoiceContentType.unknown,
    this.language,
    this.containsSensitiveData = false,
    this.detectedCategories = const [],
    this.willBeSentExternally = false,
  });

  /// FAIL CLOSED: unknown type treated as voice recording.
  VoiceContentType get effectiveContentType =>
      contentType == VoiceContentType.unknown
          ? VoiceContentType.voiceRecording
          : contentType;

  /// Whether the content should be blocked from external transmission.
  bool get shouldBlockExternal =>
      containsSensitiveData && willBeSentExternally;
}

/// Result of a voice privacy check.
class VoicePrivacyResult {
  /// Whether the voice content is allowed to be processed.
  final bool isAllowed;

  /// The redacted transcription (if applicable).
  final String? redactedTranscription;

  /// The reason for denial (if blocked).
  final String? denialReason;

  /// Sensitive categories detected.
  final List<SensitiveDataCategory> sensitiveCategories;

  /// Whether recording protection was applied.
  final bool recordingProtectionApplied;

  const VoicePrivacyResult({
    required this.isAllowed,
    this.redactedTranscription,
    this.denialReason,
    this.sensitiveCategories = const [],
    this.recordingProtectionApplied = false,
  });

  @override
  String toString() =>
      'VoicePrivacyResult(allowed: \$isAllowed, categories: \${sensitiveCategories.length}, '
      'recordingProtected: \$recordingProtectionApplied)';
}

/// Abstract application service for voice privacy.
abstract class VoicePrivacyService {
  /// Check if voice content can be processed.
  Future<SecurityResult<VoicePrivacyResult>> checkVoiceAccess(
    VoiceContentMetadata metadata, {
    String requester = 'unknown',
  });

  /// Redact a voice transcription.
  Future<SecurityResult<String>> redactTranscription(String transcription);

  /// Check if a voice command contains sensitive data.
  Future<SecurityResult<bool>> containsSensitiveCommand(String command);

  /// The current voice privacy mode.
  VoicePrivacyMode get currentMode;
}
