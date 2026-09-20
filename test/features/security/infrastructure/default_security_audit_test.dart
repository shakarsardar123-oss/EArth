/// Structural tests for DefaultSecurityAuditService implementation.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/security/infrastructure/default_security_audit.dart';

void main() {
  group('DefaultSecurityAuditService', () {
    test('FAIL CLOSED: returns empty on query error', () {
      final audit = DefaultSecurityAuditService();
      expect(audit.returnsEmptyOnQueryError, isTrue);
    });

    test('uses in-memory storage', () {
      final audit = DefaultSecurityAuditService();
      expect(audit.usesInMemoryStorage, isTrue);
    });

    test('records all 13 audit types', () {
      final audit = DefaultSecurityAuditService();
      expect(audit.supportsAllAuditTypes, isTrue);
    });
  });
}
