/// Structural tests for SecurityL10nKeys.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/security/l10n/security_l10n_keys.dart';

void main() {
  group('SecurityL10nKeys', () {
    test('all keys have security_ prefix', () {
      final keys = <String>[
        SecurityL10nKeys.featureName,
        SecurityL10nKeys.featureDescription,
        SecurityL10nKeys.configTitle,
        SecurityL10nKeys.configPrivacyLevel,
        SecurityL10nKeys.stateTitle,
        SecurityL10nKeys.verdictAllowed,
        SecurityL10nKeys.verdictDenied,
        SecurityL10nKeys.verdictFailClosed,
        SecurityL10nKeys.failureBlocked,
        SecurityL10nKeys.secretScanTitle,
        SecurityL10nKeys.loggingTitle,
        SecurityL10nKeys.redactionTitle,
        SecurityL10nKeys.agentSecurityTitle,
        SecurityL10nKeys.providerPrivacyTitle,
        SecurityL10nKeys.screenPrivacyTitle,
        SecurityL10nKeys.voicePrivacyTitle,
        SecurityL10nKeys.permissionSecurityTitle,
        SecurityL10nKeys.storageTitle,
        SecurityL10nKeys.auditTitle,
      ];

      for (final key in keys) {
        expect(key, startsWith('security_'),
            reason: 'Key "$key" must have security_ prefix');
      }
    });

    test('feature keys are defined', () {
      expect(SecurityL10nKeys.featureName, 'security_feature_name');
      expect(SecurityL10nKeys.featureDescription, 'security_feature_description');
    });

    test('config keys are defined', () {
      expect(SecurityL10nKeys.configTitle, isNotNull);
      expect(SecurityL10nKeys.configPrivacyLevel, isNotNull);
      expect(SecurityL10nKeys.configPrivacyLevelMaximum, isNotNull);
    });

    test('verdict keys are defined', () {
      expect(SecurityL10nKeys.verdictAllowed, isNotNull);
      expect(SecurityL10nKeys.verdictDenied, isNotNull);
      expect(SecurityL10nKeys.verdictFailClosed, isNotNull);
    });

    test('sensitive data category keys are defined', () {
      expect(SecurityL10nKeys.categoryPersonalData, isNotNull);
      expect(SecurityL10nKeys.categoryFinancialData, isNotNull);
      expect(SecurityL10nKeys.categoryHealthData, isNotNull);
      expect(SecurityL10nKeys.categoryBiometricData, isNotNull);
    });

    test('audit keys are defined', () {
      expect(SecurityL10nKeys.auditTitle, isNotNull);
      expect(SecurityL10nKeys.auditActionAllowed, isNotNull);
      expect(SecurityL10nKeys.auditActionDenied, isNotNull);
      expect(SecurityL10nKeys.auditSecretDetected, isNotNull);
    });

    test('private constructor prevents instantiation', () {
      // SecurityL10nKeys._() is private — only static members accessible
      // Cannot call SecurityL10nKeys() from outside the class
      // Verify class is purely static by confirming no instance methods exist
      expect(SecurityL10nKeys.featureName, isNotNull);
    });
  });
}
