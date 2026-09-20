/// Structural tests for SecretScannerService domain contract.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/security/domain/services/secret_scanner_service.dart';

void main() {
  group('DetectedSecret', () {
    test('shouldBlock always returns true (FAIL CLOSED)', () {
      final secret = DetectedSecret(
        type: 'aws_access_key',
        value: 'AKIA...',
        startIndex: 0,
        endIndex: 20,
        confidence: 0.9,
      );
      expect(secret.shouldBlock, isTrue);
    });

    test('shouldBlock is true even with low confidence', () {
      final secret = DetectedSecret(
        type: 'possible_token',
        value: 'abc...',
        startIndex: 5,
        endIndex: 15,
        confidence: 0.1,
      );
      expect(secret.shouldBlock, isTrue);
    });
  });

  group('SecretScanResult', () {
    test('shouldBlockContent is true when secrets are found', () {
      final result = SecretScanResult(
        hasSecrets: true,
        isInconclusive: false,
        detectedSecrets: [
          DetectedSecret(
            type: 'api_key',
            value: 'key...',
            startIndex: 0,
            endIndex: 10,
            confidence: 0.95,
          ),
        ],
      );
      expect(result.shouldBlockContent, isTrue);
    });

    test('FAIL CLOSED: shouldBlockContent is true when inconclusive', () {
      final result = SecretScanResult(
        hasSecrets: false,
        isInconclusive: true,
        detectedSecrets: [],
      );
      expect(result.shouldBlockContent, isTrue);
    });

    test('shouldBlockContent is false only when clean and conclusive', () {
      final result = SecretScanResult(
        hasSecrets: false,
        isInconclusive: false,
        detectedSecrets: [],
      );
      expect(result.shouldBlockContent, isFalse);
    });
  });
}
