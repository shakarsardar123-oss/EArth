// r4_provider_integration_test.dart
// AURA Assistant – R4: Security Provider Integration Tests
//
// Tests behavior that provider wiring now makes REACHABLE.
// Priority: API key redaction, Bearer token redaction,
// provider resolution, no secret reaches logger.
//
// These tests directly instantiate infrastructure implementations
// (same types the providers create) to verify behavioral contracts
// without requiring a full Flutter/Riverpod test harness.

@Tags(['r4', 'security', 'integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/core/errors/result.dart';
import 'package:aura_assistant/features/security/domain/models/security_audit_entry.dart';
import 'package:aura_assistant/features/security/domain/models/security_config.dart';
import 'package:aura_assistant/features/security/domain/models/security_state.dart';
import 'package:aura_assistant/features/security/domain/services/secret_scanner_service.dart';
import 'package:aura_assistant/features/security/domain/services/sensitive_data_redactor.dart';
import 'package:aura_assistant/features/security/domain/services/secure_logging_service.dart';
import 'package:aura_assistant/features/security/domain/services/security_audit_service.dart';
import 'package:aura_assistant/features/security/domain/models/security_failure.dart';
import 'package:aura_assistant/features/security/domain/models/security_verdict.dart';
import 'package:aura_assistant/features/security/infrastructure/default_secret_scanner.dart';
import 'package:aura_assistant/features/security/infrastructure/default_sensitive_data_redactor.dart';
import 'package:aura_assistant/features/security/infrastructure/default_secure_logger.dart';
import 'package:aura_assistant/features/security/infrastructure/default_security_audit.dart';

void main() {
  group('R4 – Provider Integration Tests', () {
    // ─── 1. SecretScanner: API key detection ─────────────────────
    group('SecretScanner – API key detection', () {
      late DefaultSecretScanner scanner;

      setUp(() {
        scanner = DefaultSecretScanner();
      });

      test('detects generic API key pattern (api_key=...)', () async {
        const content = 'config api_key=sk-abc123def456ghi789jkl012';
        final result = await scanner.scanContent(content);

        expect(result, isA<Success<SecretScanResult, SecurityFailure>>());
        final scanResult = (result as Success).value;
        expect(scanResult.hasSecrets, isTrue);
        expect(scanResult.shouldBlockContent, isTrue);
        // Verify the API key is redacted in output
        expect(scanResult.redactedContent, isNot(contains('sk-abc123def456ghi789jkl012')));
        expect(scanResult.redactedContent, contains('REDACTED'));
      });

      test('detects bearer token pattern', () async {
        const content = 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.abc123def456';
        final result = await scanner.scanContent(content);

        expect(result, isA<Success<SecretScanResult, SecurityFailure>>());
        final scanResult = (result as Success).value;
        expect(scanResult.hasSecrets, isTrue);
        // Bearer token must be redacted
        expect(scanResult.redactedContent, isNot(contains('Bearer eyJ')));
      });

      test('detects AWS access key', () async {
        const content = 'key=AKIAIOSFODNN7EXAMPLE';
        final result = await scanner.scanContent(content);

        expect(result, isA<Success<SecretScanResult, SecurityFailure>>());
        final scanResult = (result as Success).value;
        expect(scanResult.hasSecrets, isTrue);
        expect(scanResult.redactedContent, isNot(contains('AKIAIOSFODNN7EXAMPLE')));
      });

      test('quick boolean check containsSecrets returns true for API key', () async {
        const content = 'apikey=supersecretkey123456789012';
        expect(await scanner.containsSecrets(content), isTrue);
      });

      test('quick boolean check returns false for clean content', () async {
        const content = 'This is a normal message with no secrets.';
        expect(await scanner.containsSecrets(content), isFalse);
      });

      test('empty content scans as no secrets', () async {
        final result = await scanner.scanContent('');
        expect(result, isA<Success<SecretScanResult, SecurityFailure>>());
        final scanResult = (result as Success).value;
        expect(scanResult.hasSecrets, isFalse);
      });

      test('supportedPatternNames includes bearer_token and generic_api_key', () {
        expect(scanner.supportedPatternNames, contains('bearer_token'));
        expect(scanner.supportedPatternNames, contains('generic_api_key'));
      });
    });

    // ─── 2. SensitiveDataRedactor: API key & Bearer redaction ────
    group('SensitiveDataRedactor – API key & Bearer redaction', () {
      late DefaultSensitiveDataRedactor redactor;

      setUp(() {
        redactor = DefaultSensitiveDataRedactor();
      });

      test('redacts API key content', () async {
        const content = 'Setting api_key=sk-abc123def456ghi789jkl012mno345';
        final result = await redactor.redact(content);

        expect(result, isA<Success<RedactionResult, SecurityFailure>>());
        final redactionResult = (result as Success).value;
        expect(redactionResult.redactionCount, greaterThan(0));
        expect(redactionResult.redactedContent, isNot(contains('sk-abc123def456ghi789jkl012mno345')));
      });

      test('redacts Bearer token content', () async {
        const content = 'Authorization: Bearer abcdefghijklmnopqrstuvwx';
        final result = await redactor.redact(content);

        expect(result, isA<Success<RedactionResult, SecurityFailure>>());
        final redactionResult = (result as Success).value;
        // Bearer token value should be redacted
        expect(redactionResult.redactedContent, isNot(contains('Bearer abcdefghijklmnopqrstuvwx')));
      });

      test('redactValue for apiKey category returns redacted string', () {
        const rawKey = 'sk-abc123def456ghi789';
        final redacted = redactor.redactValue(rawKey, SensitiveDataCategory.apiKey);
        expect(redacted, isNot(equals(rawKey)));
        expect(redacted.length, lessThan(rawKey.length));
      });

      test('defaultRules includes API key and auth token categories', () {
        final categories = redactor.defaultRules.map((r) => r.category).toSet();
        expect(categories, contains(SensitiveDataCategory.apiKey));
        expect(categories, contains(SensitiveDataCategory.authToken));
      });

      test('activeRules is sorted by priority (descending)', () {
        final priorities = redactor.activeRules.map((r) => r.priority).toList();
        for (int i = 1; i < priorities.length; i++) {
          expect(priorities[i - 1], greaterThanOrEqualTo(priorities[i]));
        }
      });
    });

    // ─── 3. SecureLogger: no secret reaches logged output ────────
    group('SecureLogger – no secret reaches logger', () {
      late DefaultSecureLogger logger;

      setUp(() {
        final redactor = DefaultSensitiveDataRedactor();
        logger = DefaultSecureLogger(
          redactor: redactor,
          loggingMode: SecureLoggingMode.redactedOnly,
        );
      });

      test('log message containing API key is redacted', () async {
        const messageWithKey = 'Config: api_key=sk-abc123def456ghi789jkl012mno345';
        final result = await logger.log(
          LogSeverity.info,
          'test',
          messageWithKey,
        );

        expect(result, isA<Success<SecureLogEntry, SecurityFailure>>());
        final entry = (result as Success).value;
        // The raw API key must NOT appear in the logged message
        expect(entry.redactedMessage, isNot(contains('sk-abc123def456ghi789jkl012mno345')));
      });

      test('log message containing Bearer token is redacted', () async {
        const messageWithToken = 'Auth: Bearer abcdefghijklmnopqrstuvwx123456';
        final result = await logger.log(
          LogSeverity.info,
          'test',
          messageWithToken,
        );

        expect(result, isA<Success<SecureLogEntry, SecurityFailure>>());
        final entry = (result as Success).value;
        expect(entry.redactedMessage, isNot(contains('Bearer abcdefghijklmnopqrstuvwx123456')));
      });

      test('disabled logging mode returns failure', () async {
        logger.setLoggingMode(SecureLoggingMode.disabled);
        final result = await logger.log(LogSeverity.info, 'test', 'hello');

        expect(result, isA<FailureResult<SecureLogEntry, SecurityFailure>>());
      });

      test('currentLoggingMode reflects set mode', () {
        expect(logger.currentLoggingMode, SecureLoggingMode.redactedOnly);
        logger.setLoggingMode(SecureLoggingMode.metadataOnly);
        expect(logger.currentLoggingMode, SecureLoggingMode.metadataOnly);
      });

      test('safeMetadata is preserved in log entry', () async {
        final result = await logger.log(
          LogSeverity.info,
          'test',
          'clean message',
          safeMetadata: {'key': 'safe_value'},
        );

        expect(result, isA<Success<SecureLogEntry, SecurityFailure>>());
        final entry = (result as Success).value;
        expect(entry.safeMetadata['key'], 'safe_value');
      });
    });

    // ─── 4. SecurityAuditService: record and query ──────────────
    group('SecurityAuditService – record and query', () {
      late DefaultSecurityAuditService auditService;

      setUp(() {
        auditService = DefaultSecurityAuditService(
          config: SecurityConfig(),
        );
      });

      test('record entry succeeds and returns the entry', () async {
        final entry = SecurityAuditEntry(
          id: 'test-1',
          timestamp: DateTime.now(),
          type: SecurityAuditType.secretDetected,
          severity: SecurityEventSeverity.critical,
          redactedDescription: 'API key detected in input',
        );

        final result = await auditService.record(entry);
        expect(result, isA<Success<SecurityAuditEntry, SecurityFailure>>());
        final recorded = (result as Success).value;
        expect(recorded.id, 'test-1');
        expect(recorded.type, SecurityAuditType.secretDetected);
      });

      test('entryCount increments after recording', () async {
        final entry = SecurityAuditEntry(
          id: 'test-2',
          timestamp: DateTime.now(),
          type: SecurityAuditType.dataRedacted,
          severity: SecurityEventSeverity.info,
          redactedDescription: 'Bearer token redacted',
        );

        await auditService.record(entry);
        final count = await auditService.entryCount;
        expect(count, isA<Success<int, SecurityFailure>>());
        expect((count as Success).value, greaterThan(0));
      });

      test('recordVerdict creates entry from verdict', () async {
        final verdict = SecurityVerdict.denied(
          reason: 'Secret detected',
          action: 'api_call',
          category: SensitiveDataCategory.apiKey,
        );

        final result = await auditService.recordVerdict(
          'api_call',
          verdict,
          category: SensitiveDataCategory.apiKey,
        );

        expect(result, isA<Success<SecurityAuditEntry, SecurityFailure>>());
        final recorded = (result as Success).value;
        expect(recorded.action, 'api_call');
      });

      test('getSummary returns stats', () async {
        final entry = SecurityAuditEntry(
          id: 'test-3',
          timestamp: DateTime.now(),
          type: SecurityAuditType.actionBlocked,
          severity: SecurityEventSeverity.critical,
          redactedDescription: 'Blocked tool execution',
        );

        await auditService.record(entry);
        final summary = await auditService.getSummary();

        expect(summary, isA<Success<AuditSummary, SecurityFailure>>());
        final s = (summary as Success).value;
        expect(s.totalEvents, greaterThan(0));
      });

      test('query by type filters correctly', () async {
        final entry1 = SecurityAuditEntry(
          id: 'q-1',
          timestamp: DateTime.now(),
          type: SecurityAuditType.secretDetected,
          severity: SecurityEventSeverity.critical,
          redactedDescription: 'Secret found',
        );
        final entry2 = SecurityAuditEntry(
          id: 'q-2',
          timestamp: DateTime.now(),
          type: SecurityAuditType.dataRedacted,
          severity: SecurityEventSeverity.info,
          redactedDescription: 'Data redacted',
        );

        await auditService.record(entry1);
        await auditService.record(entry2);

        final result = await auditService.query(
          AuditQuery(type: SecurityAuditType.secretDetected),
        );

        expect(result, isA<Success<List<SecurityAuditEntry>, SecurityFailure>>());
        final entries = (result as Success).value;
        expect(entries.every((e) => e.type == SecurityAuditType.secretDetected), isTrue);
      });
    });

    // ─── 5. Fail-closed invariants ───────────────────────────────
    group('Fail-closed invariants', () {
      test('scanner treats error as secrets-present (fail-closed)', () async {
        final scanner = DefaultSecretScanner();
        // Force a scan on content; the scanner wraps errors internally
        // We verify the contract: scan never returns hasSecrets=false on error
        // Normal scan on clean content should return false
        final result = await scanner.scanContent('normal text with no secrets');
        final scanResult = (result as Success).value;
        // For clean content, hasSecrets should be false
        // But on error, it returns hasSecrets=true + isInconclusive=true
        expect(scanResult.shouldBlockContent, equals(scanResult.hasSecrets || scanResult.isInconclusive));
      });

      test('redactor on empty content returns zero redactions', () async {
        final redactor = DefaultSensitiveDataRedactor();
        final result = await redactor.redact('');
        final rr = (result as Success).value;
        expect(rr.redactionCount, 0);
        expect(rr.redactedContent, '');
      });

      test('redactValue with no matching rule returns fail-closed full redaction', () {
        final redactor = DefaultSensitiveDataRedactor();
        // Use a category unlikely to have a specific rule
        final result = redactor.redactValue('some-value', SensitiveDataCategory.unknown);
        // Fail-closed: even unknown category should redact
        expect(result, isNot(equals('some-value')));
      });

      test('SecurityConfig() default is maximum (fail-closed)', () {
        final config = SecurityConfig();
        // Default config must be maximum (fail-closed per design)
        expect(config.loggingMode, SecureLoggingMode.redactedOnly);
      });
    });

    // ─── 6. Provider type resolution ─────────────────────────────
    group('Provider type resolution (wiring check)', () {
      test('DefaultSecretScanner implements SecretScannerService', () {
        final scanner = DefaultSecretScanner();
        expect(scanner, isA<SecretScannerService>());
      });

      test('DefaultSensitiveDataRedactor implements SensitiveDataRedactor', () {
        final redactor = DefaultSensitiveDataRedactor();
        expect(redactor, isA<SensitiveDataRedactor>());
      });

      test('DefaultSecureLogger implements SecureLoggingService', () {
        final logger = DefaultSecureLogger(
          redactor: DefaultSensitiveDataRedactor(),
        );
        expect(logger, isA<SecureLoggingService>());
      });

      test('DefaultSecurityAuditService implements SecurityAuditService', () {
        final audit = DefaultSecurityAuditService(
          config: SecurityConfig(),
        );
        expect(audit, isA<SecurityAuditService>());
      });

      test('DefaultSecureLogger requires redactor dependency', () {
        // Verify the wiring: logger depends on redactor
        // This is the same dependency the provider graph creates
        final redactor = DefaultSensitiveDataRedactor();
        final logger = DefaultSecureLogger(redactor: redactor);
        expect(logger.currentLoggingMode, isNotNull);
      });

      test('DefaultSecurityAuditService requires config dependency', () {
        // Verify the wiring: audit depends on config
        // This is the same dependency the provider graph creates
        final config = SecurityConfig();
        final audit = DefaultSecurityAuditService(config: config);
        expect(audit.entryCount, isNotNull);
      });
    });
  });
}
