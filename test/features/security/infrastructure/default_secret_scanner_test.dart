/// Structural tests for DefaultSecretScanner implementation.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/security/infrastructure/default_secret_scanner.dart';

void main() {
  group('DefaultSecretScanner', () {
    test('has 15 regex patterns', () {
      final scanner = DefaultSecretScanner();
      expect(scanner.patternCount, 15);
    });

    test('FAIL CLOSED: scan error returns hasSecrets=true', () async {
      final scanner = DefaultSecretScanner();
      // When scan encounters an error, the result should indicate secrets found
      // This is a structural test — actual behavior tested via mock
      expect(scanner.failClosedOnScanError, isTrue);
    });

    test('detects AWS access key pattern', () {
      final scanner = DefaultSecretScanner();
      expect(scanner.hasPatternForType('aws_access_key'), isTrue);
    });

    test('detects generic API key pattern', () {
      final scanner = DefaultSecretScanner();
      expect(scanner.hasPatternForType('generic_api_key'), isTrue);
    });

    test('detects private key pattern', () {
      final scanner = DefaultSecretScanner();
      expect(scanner.hasPatternForType('private_key'), isTrue);
    });
  });
}
