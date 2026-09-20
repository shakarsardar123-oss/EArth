/// Structural tests for SecurityFailure domain model.
/// No Flutter/Dart SDK — structural/mock tests only.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/security/domain/models/security_failure.dart';

void main() {
  group('SecurityFailure', () {
    test('isBlocked always returns true for every factory constructor', () {
      final failures = <SecurityFailure>[
        SecurityFailure.secretDetected(
          action: 'scan',
          cause: 'apiKey_found',
          message: 'API key detected',
        ),
        SecurityFailure.actionDenied(
          action: 'delete_file',
          cause: 'prohibited',
          message: 'Action prohibited',
        ),
        SecurityFailure.redactionFailed(
          action: 'log',
          cause: 'regex_error',
          message: 'Redaction failed',
        ),
        SecurityFailure.memoryViolation(
          action: 'recall',
          cause: 'sensitive_data',
          message: 'Memory policy violation',
        ),
        SecurityFailure.permissionDenied(
          action: 'camera_access',
          cause: 'security_policy',
          message: 'Permission denied by security',
        ),
        SecurityFailure.providerViolation(
          action: 'api_call',
          cause: 'unauthorized_provider',
          message: 'Provider violation',
        ),
        SecurityFailure.screenCaptureBlocked(
          action: 'screenshot',
          cause: 'sensitive_app',
          message: 'Screen capture blocked',
        ),
        SecurityFailure.voiceRecordingBlocked(
          action: 'record',
          cause: 'sensitive_content',
          message: 'Voice recording blocked',
        ),
        SecurityFailure.storageCompromised(
          action: 'read',
          cause: 'tamper_detected',
          message: 'Storage compromised',
        ),
        SecurityFailure.configViolation(
          action: 'update_config',
          cause: 'invalid_value',
          message: 'Config violation',
        ),
        SecurityFailure.auditFailure(
          action: 'query_audit',
          cause: 'db_error',
          message: 'Audit failure',
        ),
        SecurityFailure.recoveryFailed(
          action: 'recover',
          cause: 'unrecoverable',
          message: 'Recovery failed',
        ),
        SecurityFailure.unknown(
          action: 'unknown',
          cause: 'unknown',
          message: 'Unknown failure',
        ),
      ];

      for (final failure in failures) {
        expect(failure.isBlocked, isTrue,
            reason: 'isBlocked must always be true (FAIL CLOSED): ${failure.action}');
      }
    });

    test('factory constructors populate action, cause, message', () {
      final failure = SecurityFailure.secretDetected(
        action: 'scan_text',
        cause: 'aws_key',
        message: 'AWS secret key found',
      );

      expect(failure.action, 'scan_text');
      expect(failure.cause, 'aws_key');
      expect(failure.message, 'AWS secret key found');
    });

    test('asFailure<T> wraps SecurityFailure as Failure<T, SecurityFailure>', () {
      final failure = SecurityFailure.permissionDenied(
        action: 'location',
        cause: 'denied',
        message: 'Location denied',
      );

      final result = failure.asFailure<String>();
      // Must be a Failure subtype — valueOrNull is null
      expect(result.valueOrNull, isNull);
      expect(result.failureOrNull, isNotNull);
    });

    test('SecurityFailurePhase enum has 16 phases', () {
      expect(SecurityFailurePhase.values.length, 16);
    });

    test('SecurityFailurePhase covers all major security areas', () {
      final phaseNames = SecurityFailurePhase.values.map((p) => p.name).toList();
      expect(phaseNames, containsAll([
        'secretDetection',
        'actionValidation',
        'redaction',
        'memoryPrivacy',
        'permissionCheck',
        'providerPrivacy',
        'screenPrivacy',
        'voicePrivacy',
        'secureStorage',
        'configuration',
        'audit',
        'recovery',
      ]));
    });
  });
}
