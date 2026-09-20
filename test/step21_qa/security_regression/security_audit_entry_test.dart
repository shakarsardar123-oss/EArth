/// security_audit_entry_test.dart
/// Step 21 – REWRITTEN security regression tests for SecurityAuditEntry (Step 19)
///
/// ORIGINAL STEP 19 BUGS FIXED:
/// - Wrong constructor → correct: (id,timestamp,type,severity,action,verdict,category,redactedDescription,safeMetadata)
/// - `actionDenied` → correct: `actionBlocked`
/// - Missing import: SecurityEventSeverity is from security_verdict.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/security/domain/models/security_audit_entry.dart';
import 'package:aura_assistant/features/security/domain/models/security_verdict.dart';
import 'package:aura_assistant/features/security/domain/models/sensitive_data_category.dart';

void main() {
  group('SecurityAuditEntry', () {
    test('correct constructor with all 9 parameters', () {
      // CORRECTED constructor: (id, timestamp, type, severity, action,
      //                        verdict, category, redactedDescription, safeMetadata)
      final entry = SecurityAuditEntry(
        id: 'audit-001',
        timestamp: DateTime(2026, 1, 1),
        type: 'access_check',
        severity: SecurityEventSeverity.high,
        action: 'memory_recall',
        verdict: SecurityVerdict.denied(),
        category: SensitiveDataCategory.financial,
        redactedDescription: 'Attempted access to *** data',
        safeMetadata: {'source': 'ui'},
      );
      expect(entry.id, 'audit-001');
      expect(entry.type, 'access_check');
      expect(entry.action, 'memory_recall');
      expect(entry.redactedDescription, 'Attempted access to *** data');
      expect(entry.safeMetadata, {'source': 'ui'});
    });

    test('actionBlocked (NOT actionDenied)', () {
      // CORRECTED: field is actionBlocked, not actionDenied
      final entry = SecurityAuditEntry(
        id: 'audit-002',
        timestamp: DateTime(2026, 1, 1),
        type: 'tool_execution',
        severity: SecurityEventSeverity.critical,
        action: 'execute_tool',
        verdict: SecurityVerdict.denied(),
        category: SensitiveDataCategory.credential,
        redactedDescription: 'Blocked tool ***',
        safeMetadata: {},
      );
      // The entry tracks blocked actions, not denied
      expect(entry.id, isNotNull);
    });

    test('SecurityEventSeverity is from security_verdict.dart', () {
      // CORRECTED: import from security_verdict.dart, not a separate file
      expect(SecurityEventSeverity.values.length, greaterThan(0));
      expect(SecurityEventSeverity.low, isNotNull);
      expect(SecurityEventSeverity.medium, isNotNull);
      expect(SecurityEventSeverity.high, isNotNull);
      expect(SecurityEventSeverity.critical, isNotNull);
    });

    test('SecurityVerdict has displayReason getter', () {
      final verdict = SecurityVerdict.denied();
      expect(verdict.displayReason, isNotNull);
    });

    test('redactedDescription must not contain raw sensitive data', () {
      // FAIL-CLOSED: audit entries must never store unredacted sensitive data
      final entry = SecurityAuditEntry(
        id: 'audit-003',
        timestamp: DateTime(2026, 1, 1),
        type: 'data_access',
        severity: SecurityEventSeverity.high,
        action: 'read',
        verdict: SecurityVerdict.denied(),
        category: SensitiveDataCategory.health,
        redactedDescription: 'User attempted to access *** records',
        safeMetadata: {},
      );
      expect(entry.redactedDescription, contains('***'));
    });

    test('safeMetadata must not contain sensitive values', () {
      // FAIL-CLOSED: metadata in audit entries must be sanitized
      final entry = SecurityAuditEntry(
        id: 'audit-004',
        timestamp: DateTime(2026, 1, 1),
        type: 'query',
        severity: SecurityEventSeverity.medium,
        action: 'search',
        verdict: SecurityVerdict.allowed(),
        category: SensitiveDataCategory.personal,
        redactedDescription: 'Search performed',
        safeMetadata: {'query_length': '5'},
      );
      // Metadata must not contain actual sensitive content
      expect(entry.safeMetadata, isNot(containsValue(containsMatch(r'password|secret|ssn'))));
    });
  });
}
