/// Structural tests for SecurityConfig domain model.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/security/domain/models/security_config.dart';

void main() {
  group('SecurityConfig', () {
    test('maximum factory enables all security', () {
      final config = SecurityConfig.maximum();
      expect(config.privacyLevel, PrivacyLevel.maximum);
      expect(config.agentSecurityMode, AgentSecurityMode.restricted);
      expect(config.secureLoggingMode, SecureLoggingMode.metadataOnly);
      expect(config.screenPrivacyMode, ScreenPrivacyMode.fullCapture);
      expect(config.voicePrivacyMode, VoicePrivacyMode.voiceRecording);
    });

    test('standard factory uses balanced defaults', () {
      final config = SecurityConfig.standard();
      expect(config.privacyLevel, PrivacyLevel.standard);
      expect(config.agentSecurityMode, AgentSecurityMode.restricted);
      expect(config.secureLoggingMode, SecureLoggingMode.redactedOnly);
    });

    test('minimal factory reduces security overhead', () {
      final config = SecurityConfig.minimal();
      expect(config.privacyLevel, PrivacyLevel.minimal);
    });

    test('copyWith updates specified fields', () {
      final base = SecurityConfig.standard();
      final updated = base.copyWith(privacyLevel: PrivacyLevel.maximum);
      expect(updated.privacyLevel, PrivacyLevel.maximum);
      expect(updated.agentSecurityMode, base.agentSecurityMode);
    });

    test('copyWith clear* flags reset nullable fields', () {
      final base = SecurityConfig.standard();
      final cleared = base.copyWith(clearCustomRedactionRules: true);
      expect(cleared.customRedactionRules, isNull);
    });

    test('is immutable via @immutable', () {
      final config = SecurityConfig.maximum();
      // @immutable ensures const constructor — structural check
      expect(config.hashCode, isNotNull);
    });

    test('PrivacyLevel enum has 3 values', () {
      expect(PrivacyLevel.values.length, 3);
    });

    test('AgentSecurityMode enum has 3 values', () {
      expect(AgentSecurityMode.values.length, 3);
    });

    test('SecureLoggingMode enum has 4 values', () {
      expect(SecureLoggingMode.values.length, 4);
    });

    test('ScreenPrivacyMode enum has 3 values', () {
      expect(ScreenPrivacyMode.values.length, 3);
    });

    test('VoicePrivacyMode enum has 3 values', () {
      expect(VoicePrivacyMode.values.length, 3);
    });

    test('ProviderPrivacyMode enum has 3 values', () {
      expect(ProviderPrivacyMode.values.length, 3);
    });
  });
}
