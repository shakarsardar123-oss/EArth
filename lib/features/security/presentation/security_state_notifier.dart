/// security_state_notifier.dart
/// AURA Assistant – Step 19: Security & Privacy Hardening
///
/// StateNotifier for SecurityState, coordinating all security
/// operations and maintaining reactive state for the UI.
///
/// FAIL CLOSED: if initialization fails or state is inconsistent,
/// the system defaults to maximum security (most restrictive config).
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aura_assistant/core/errors/result.dart' show Result, Success, Failure;
import '../application/secure_storage_service.dart';
import '../domain/models/security_audit_entry.dart';
import '../domain/models/security_config.dart';
import '../domain/models/security_failure.dart';
import '../domain/models/security_state.dart';
import '../domain/models/security_verdict.dart';
import '../domain/services/secret_scanner_service.dart';
import '../domain/services/secure_logging_service.dart';
import '../domain/services/sensitive_data_redactor.dart';
import '../domain/services/security_audit_service.dart';
import '../../../core/errors/result.dart';

class SecurityStateNotifier extends StateNotifier<SecurityState> {
  final SecretScannerService _scanner;
  final SensitiveDataRedactor _redactor;
  final SecurityAuditService _auditService;
  final SecureLoggingService _logger;
  final SecureStorageService _storage;

  final StreamController<SecurityState> _stateStreamController =
      StreamController<SecurityState>.broadcast();

  SecurityStateNotifier({
    required SecurityConfig config,
    required SecretScannerService scanner,
    required SensitiveDataRedactor redactor,
    required SecurityAuditService auditService,
    required SecureLoggingService logger,
    required SecureStorageService storage,
  })  : _scanner = scanner,
        _redactor = redactor,
        _auditService = auditService,
        _logger = logger,
        _storage = storage,
        super(SecurityState(
          config: config,
          isLoading: false,
        ));

  /// Stream of state changes for reactive consumption.
  Stream<SecurityState> get stateStream => _stateStreamController.stream;

  /// Whether the security subsystem is ready.
  bool get isReady =>
      !state.isLoading && state.activeSecurityOperation == null;

  /// Current security configuration.
  SecurityConfig get currentConfig => state.config;

  /// Initialize the security subsystem.
  Future<void> initialize() async {
    state = state.copyWith(isLoading: true);
    _emit();

    try {
      // Verify secure storage availability
      final available = await _storage.isAvailable;
      if (!available) {
        // FAIL CLOSED: if storage unavailable, use maximum config
        state = state.copyWith(
          config: SecurityConfig.maximum(),
          isLoading: false,
        );
        _emit();
    _recordAudit(
          type: SecurityAuditType.initialization,
          severity: SecurityEventSeverity.critical,
          action: 'initialize',
          description:
              'Secure storage unavailable — using maximum security config',
        );
        return;
      }

      state = state.copyWith(isLoading: false);
      _emit();

      _recordAudit(
        type: SecurityAuditType.initialization,
        severity: SecurityEventSeverity.info,
        action: 'initialize',
        description: 'Security subsystem initialized',
      );
    } catch (e) {
      // FAIL CLOSED: on error, use maximum config
      state = state.copyWith(
        config: SecurityConfig.maximum(),
        isLoading: false,
      );
      _emit();
      _recordAudit(
        type: SecurityAuditType.initialization,
        severity: SecurityEventSeverity.critical,
        action: 'initialize',
        description:
            'Initialization failed — using maximum security config',
      );
    }
  }

  /// Scan content for secrets.
  Future<SecurityResult<SecretScanResult>> scanForSecrets(
    String content,
  ) async {
    state = state.copyWith(
      activeSecurityOperation: 'scanForSecrets',
    );
    _emit();

    try {
      final result = await _scanner.scanContent(content);

      return result.fold(
        onSuccess: (scanResult) {
          if (scanResult.shouldBlockContent) {
            state = state.copyWith(
              secretsDetectedCount: state.secretsDetectedCount + 1,
              actionsBlockedCount: state.actionsBlockedCount + 1,
              activeSecurityOperation: null,
            );
            _emit();
            _recordAudit(
              type: SecurityAuditType.secretDetected,
              severity: SecurityEventSeverity.critical,
              action: 'scanForSecrets',
              description: 'Secret detected — content blocked',
            );
          } else {
            state = state.copyWith(
              activeSecurityOperation: null,
            );
            _emit();
          }
          return result;
        },
        onFailure: (failure) {
          // FAIL CLOSED: treat scan failure as detection
          state = state.copyWith(
            secretsDetectedCount: state.secretsDetectedCount + 1,
            actionsBlockedCount: state.actionsBlockedCount + 1,
            activeSecurityOperation: null,
          );
          _emit();
          return result;
        },
      );
    } catch (e) {
      // FAIL CLOSED: on error, treat as secret detected
      state = state.copyWith(
        secretsDetectedCount: state.secretsDetectedCount + 1,
        actionsBlockedCount: state.actionsBlockedCount + 1,
        activeSecurityOperation: null,
      );
      _emit();
      return SecurityFailure.unknown(
        action: 'scanForSecrets',
        cause: 'Scan error — content treated as containing secrets (fail closed)',
        message: 'Secret scan failed — content treated as containing secrets',
      ).asFailure<SecretScanResult>();
    }
  }

  /// Redact content to remove sensitive data.
  Future<SecurityResult<String>> redactContent(
    String content,
  ) async {
    state = state.copyWith(
      activeSecurityOperation: 'redactContent',
    );
    _emit();

    try {
      final result = await _redactor.redact(content);

      return result.fold(
        onSuccess: (redactionResult) {
          state = state.copyWith(
            redactionsAppliedCount: state.redactionsAppliedCount +
                redactionResult.redactionCount,
            activeSecurityOperation: null,
          );
          _emit();
          return Success(redactionResult.redactedContent);
        },
        onFailure: (failure) {
          // FAIL CLOSED: on redaction failure, fully redact
          state = state.copyWith(
            redactionsAppliedCount: state.redactionsAppliedCount + 1,
            activeSecurityOperation: null,
          );
          _emit();
          return Success('[CONTENT REDACTED: ERROR]');
        },
      );
    } catch (e) {
      // FAIL CLOSED
      state = state.copyWith(
        redactionsAppliedCount: state.redactionsAppliedCount + 1,
        activeSecurityOperation: null,
      );
      _emit();
      return Success('[CONTENT REDACTED: ERROR]');
    }
  }

  /// Evaluate a security action through the policy layer.
  Future<SecurityVerdict> evaluate(
    String action,
    String content, {
    SensitiveDataCategory category = SensitiveDataCategory.unknown,
  }) async {
    // Scan for secrets first
    final scanResult = await scanForSecrets(content);
    final hasSecrets = scanResult.fold(
      onSuccess: (r) => r.hasSecrets,
      onFailure: (_) => true, // FAIL CLOSED
    );

    if (hasSecrets) {
      final verdict = SecurityVerdict.failClosed(
        action: action,
        reason: 'Content contains secrets — action blocked',
      );
      _recordVerdict(verdict, category: category);
      return verdict;
    }

    // Check category-based restrictions
    if (state.config.isActionDenied(action)) {
      final verdict = SecurityVerdict.denied(
        action: action,
        reason: 'Action explicitly denied by security configuration',
        category: category,
      );
      _recordVerdict(verdict, category: category);
      return verdict;
    }

    final verdict = SecurityVerdict.allowed(
      action: action,
      reason: 'Action passed security checks',
    );
    _recordVerdict(verdict, category: category);
    return verdict;
  }

  /// Record an audit event.
  Future<void> recordAuditEvent({
    required SecurityAuditType type,
    required SecurityEventSeverity severity,
    required String action,
    required String description,
    Map<String, String> safeMetadata = const {},
  }) async {
    _recordAudit(
      type: type,
      severity: severity,
      action: action,
      description: description,
      safeMetadata: safeMetadata,
    );
  }

  /// Update the security configuration.
  Future<void> updateConfig(SecurityConfig newConfig) async {
    state = state.copyWith(config: newConfig);
    _emit();

    _logger.setLoggingMode(newConfig.loggingMode);

    _recordAudit(
      type: SecurityAuditType.configChange,
      severity: SecurityEventSeverity.warning,
      action: 'updateConfig',
      description: 'Security configuration updated',
    );
  }

  /// Get current state.
  SecurityState get currentState => state;

  @override
  void dispose() {
    _stateStreamController.close();
    super.dispose();
  }

  // ─── Private helpers ─────────────────────────────────────────────

  void _emit() {
    if (!_stateStreamController.isClosed) {
      _stateStreamController.add(state);
    }
  }

  Future<void> _recordAudit({
    required SecurityAuditType type,
    required SecurityEventSeverity severity,
    required String action,
    required String description,
    Map<String, String> safeMetadata = const {},
  }) async {
    final entry = SecurityAuditEntry(
      id: 'audit_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      type: type,
      severity: severity,
      action: action,
      redactedDescription: description,
      safeMetadata: safeMetadata,
    );

    await _auditService.record(entry);
    await _logger.logAuditEntry(entry);

    // Map to SecurityAuditEvent for state tracking
    final event = SecurityAuditEvent(
      id: 'evt_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      severity: severity,
      action: action,
      redactedDescription: description,
      category: null,
      verdict: null,
    );

    state = state.copyWith(
      recentAuditEvents: [
        event,
        ...state.recentAuditEvents.take(49), // Keep last 50
      ],
    );
    _emit();
  }

  Future<void> _recordVerdict(
    SecurityVerdict verdict, {
    SensitiveDataCategory? category,
  }) async {
    await _auditService.recordVerdict(
      verdict.action ?? 'unknown',
      verdict,
      category: category ?? verdict.category,
    );

    if (verdict.isDenied) {
      state = state.copyWith(
        actionsBlockedCount: state.actionsBlockedCount + 1,
        lastFailure: verdict.isFailClosedDenial
            ? SecurityFailure.actionBlocked(
                action: verdict.action ?? 'unknown',
                verdictReason: verdict.reason ?? 'Fail-closed denial',
              )
            : SecurityFailure.actionBlocked(
                action: verdict.action ?? 'unknown',
                verdictReason:
                    verdict.reason ?? 'Action denied by policy',
              ),
      );
      _emit();
    }
  }
}
