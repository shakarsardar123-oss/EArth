/// Structural tests for security application layer contracts.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/security/application/security_policy.dart';
import 'package:aura_assistant/features/security/application/security_controller.dart';
import 'package:aura_assistant/features/security/application/agent_security_service.dart';
import 'package:aura_assistant/features/security/application/provider_privacy_service.dart';
import 'package:aura_assistant/features/security/application/screen_privacy_service.dart';
import 'package:aura_assistant/features/security/application/voice_privacy_service.dart';
import 'package:aura_assistant/features/security/application/permission_security_service.dart';
import 'package:aura_assistant/features/security/application/secure_storage_service.dart';

void main() {
  group('SecurityCheckType', () {
    test('has all expected check types', () {
      expect(SecurityCheckType.values.length, greaterThanOrEqualTo(10));
      final names = SecurityCheckType.values.map((e) => e.name).toList();
      expect(names, containsAll([
        'secretScan',
        'actionValidation',
        'redaction',
        'memoryPrivacy',
        'permissionCheck',
        'providerPrivacy',
        'screenPrivacy',
        'voicePrivacy',
        'storageOperation',
        'configuration',
      ]));
    });
  });

  group('ActionRiskLevel', () {
    test('unknown maps to critical (FAIL CLOSED)', () {
      expect(ActionRiskLevel.unknown, ActionRiskLevel.critical);
    });

    test('has 5 risk levels', () {
      expect(ActionRiskLevel.values.length, 5);
    });
  });

  group('ActionMetadata', () {
    test('constructor populates fields', () {
      final meta = ActionMetadata(
        actionId: 'act_001',
        actionName: 'delete_file',
        toolName: 'file_manager',
        riskLevel: ActionRiskLevel.high,
      );
      expect(meta.actionId, 'act_001');
      expect(meta.toolName, 'file_manager');
    });
  });

  group('ProviderPrivacyProfile', () {
    test('constructor populates fields', () {
      final profile = ProviderPrivacyProfile(
        providerId: 'openai',
        providerName: 'OpenAI',
        requiresRedaction: true,
        sensitiveCategories: ['personal_data', 'api_key'],
      );
      expect(profile.providerId, 'openai');
      expect(profile.requiresRedaction, isTrue);
    });
  });

  group('ScreenContentType', () {
    test('unknown maps to fullCapture (FAIL CLOSED)', () {
      expect(ScreenContentType.unknown, ScreenContentType.fullCapture);
    });
  });

  group('VoiceContentType', () {
    test('unknown maps to voiceRecording (FAIL CLOSED)', () {
      expect(VoiceContentType.unknown, VoiceContentType.voiceRecording);
    });
  });

  group('PermissionSecurityRisk', () {
    test('unknown maps to critical (FAIL CLOSED)', () {
      expect(PermissionSecurityRisk.unknown, PermissionSecurityRisk.critical);
    });
  });

  group('SecureStorageDataType', () {
    test('has expected data types', () {
      expect(SecureStorageDataType.values.length, greaterThanOrEqualTo(5));
    });
  });
}
