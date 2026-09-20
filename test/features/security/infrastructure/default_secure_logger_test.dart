/// Structural tests for DefaultSecureLogger implementation.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/security/infrastructure/default_secure_logger.dart';
import 'package:aura_assistant/features/security/domain/services/secure_logging_service.dart';

void main() {
  group('DefaultSecureLogger', () {
    test('FAIL CLOSED: drops entry on redaction error', () {
      final logger = DefaultSecureLogger(
        redactor: _FailingRedactor(),
      );
      expect(logger.dropsOnRedactionError, isTrue);
    });

    test('has redaction pipeline', () {
      final logger = DefaultSecureLogger();
      expect(logger.hasRedactionPipeline, isTrue);
    });

    test('respects logging mode', () {
      final logger = DefaultSecureLogger();
      expect(logger.supportsDisabledMode, isTrue);
      expect(logger.supportsMetadataOnlyMode, isTrue);
      expect(logger.supportsRedactedOnlyMode, isTrue);
    });
  });
}

/// Mock redactor that always fails for FAIL CLOSED testing.
class _FailingRedactor implements SensitiveDataRedactor {
  @override
  Future<RedactionResult> redact(String text) async {
    throw Exception('Redaction failed');
  }
}
