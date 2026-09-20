/// security_state.dart
/// AURA Assistant – Step 19: Security & Privacy Hardening
///
/// @immutable security state model.
/// Tracks the current security posture, active protections,
/// and recent audit events.
///
/// FAIL CLOSED: missing or null state → treated as *locked down*.
library;

import 'package:flutter/foundation.dart';
import 'security_config.dart';
import 'security_failure.dart';
import 'security_verdict.dart';

/// Severity level for security audit events.
enum SecurityEventSeverity {
  /// Informational event (e.g., config change).
  info,

  /// Warning event (e.g., near-miss, over-redaction).
  warning,

  /// Critical event (e.g., blocked action, detected secret).
  critical,
}

/// A single security audit event.
class SecurityAuditEvent {
  /// Unique event ID.
  final String id;

  /// Timestamp of the event.
  final DateTime timestamp;

  /// Severity of the event.
  final SecurityEventSeverity severity;

  /// The action or operation that triggered this event.
  final String action;

  /// The security verdict for this event (if applicable).
  final SecurityVerdict? verdict;

  /// The sensitive data category (if applicable).
  final SensitiveDataCategory? category;

  /// Redacted description — never contains raw secrets.
  final String redactedDescription;

  const SecurityAuditEvent({
    required this.id,
    required this.timestamp,
    required this.severity,
    required this.action,
    this.verdict,
    this.category,
    required this.redactedDescription,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SecurityAuditEvent &&
          id == other.id &&
          timestamp == other.timestamp &&
          severity == other.severity &&
          action == other.action &&
          verdict == other.verdict &&
          category == other.category &&
          redactedDescription == other.redactedDescription;

  @override
  int get hashCode => Object.hash(
        id,
        timestamp,
        severity,
        action,
        verdict,
        category,
        redactedDescription,
      );
}

/// @immutable security state — the single source of truth for
/// the security feature's current posture.
@immutable
class SecurityState {
  /// Current security configuration.
  final SecurityConfig config;

  /// Whether the security system is initialized.
  final bool isInitialized;

  /// Whether secure storage is available.
  final bool isSecureStorageAvailable;

  /// Number of secrets detected (lifetime counter).
  final int secretsDetectedCount;

  /// Number of actions blocked (lifetime counter).
  final int actionsBlockedCount;

  /// Number of redactions applied (lifetime counter).
  final int redactionsAppliedCount;

  /// Number of privacy violations detected (lifetime counter).
  final int privacyViolationsCount;

  /// Most recent security failure (if any).
  final SecurityFailure? lastFailure;

  /// Recent audit events (capped at a maximum).
  final List<SecurityAuditEvent> recentAuditEvents;

  /// Whether a security operation is currently in progress.
  final bool isLoading;

  /// The security feature that is currently active (if any).
  final String? activeSecurityOperation;

  const SecurityState({
    this.config = const SecurityConfig(),
    this.isInitialized = false,
    this.isSecureStorageAvailable = false,
    this.secretsDetectedCount = 0,
    this.actionsBlockedCount = 0,
    this.redactionsAppliedCount = 0,
    this.privacyViolationsCount = 0,
    this.lastFailure,
    this.recentAuditEvents = const [],
    this.isLoading = false,
    this.activeSecurityOperation,
  });

  // ─── Convenience getters ──────────────────────────────────────────

  /// Whether the system is in a healthy state (no failures, initialized).
  bool get isHealthy => isInitialized && lastFailure == null;

  /// Current privacy level from config.
  PrivacyLevel get privacyLevel => config.privacyLevel;

  /// Total security events count.
  int get totalEventsCount =>
      secretsDetectedCount +
      actionsBlockedCount +
      redactionsAppliedCount +
      privacyViolationsCount;

  /// Whether there are any recent audit events.
  bool get hasAuditEvents => recentAuditEvents.isNotEmpty;

  /// Whether the last operation was a failure.
  bool get hasFailure => lastFailure != null;

  // ─── copyWith ────────────────────────────────────────────────────

  SecurityState copyWith({
    SecurityConfig? config,
    bool? isInitialized,
    bool? isSecureStorageAvailable,
    int? secretsDetectedCount,
    int? actionsBlockedCount,
    int? redactionsAppliedCount,
    int? privacyViolationsCount,
    SecurityFailure? lastFailure,
    List<SecurityAuditEvent>? recentAuditEvents,
    bool? isLoading,
    String? activeSecurityOperation,
    bool clearLastFailure = false,
    bool clearRecentAuditEvents = false,
    bool clearActiveSecurityOperation = false,
  }) {
    return SecurityState(
      config: config ?? this.config,
      isInitialized: isInitialized ?? this.isInitialized,
      isSecureStorageAvailable:
          isSecureStorageAvailable ?? this.isSecureStorageAvailable,
      secretsDetectedCount:
          secretsDetectedCount ?? this.secretsDetectedCount,
      actionsBlockedCount:
          actionsBlockedCount ?? this.actionsBlockedCount,
      redactionsAppliedCount:
          redactionsAppliedCount ?? this.redactionsAppliedCount,
      privacyViolationsCount:
          privacyViolationsCount ?? this.privacyViolationsCount,
      lastFailure:
          clearLastFailure ? null : (lastFailure ?? this.lastFailure),
      recentAuditEvents: clearRecentAuditEvents
          ? const []
          : (recentAuditEvents ?? this.recentAuditEvents),
      isLoading: isLoading ?? this.isLoading,
      activeSecurityOperation: clearActiveSecurityOperation
          ? null
          : (activeSecurityOperation ?? this.activeSecurityOperation),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SecurityState &&
          config == other.config &&
          isInitialized == other.isInitialized &&
          isSecureStorageAvailable == other.isSecureStorageAvailable &&
          secretsDetectedCount == other.secretsDetectedCount &&
          actionsBlockedCount == other.actionsBlockedCount &&
          redactionsAppliedCount == other.redactionsAppliedCount &&
          privacyViolationsCount == other.privacyViolationsCount &&
          lastFailure == other.lastFailure &&
          _listEq(recentAuditEvents, other.recentAuditEvents) &&
          isLoading == other.isLoading &&
          activeSecurityOperation == other.activeSecurityOperation;

  static bool _listEq<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        config,
        isInitialized,
        isSecureStorageAvailable,
        secretsDetectedCount,
        actionsBlockedCount,
        redactionsAppliedCount,
        privacyViolationsCount,
        lastFailure,
        Object.hashAll(recentAuditEvents),
        isLoading,
        activeSecurityOperation,
      );

  @override
  String toString() =>
      'SecurityState(healthy: \$isHealthy, privacy: \$privacyLevel, '
      'secrets: \$secretsDetectedCount, blocked: \$actionsBlockedCount, '
      'redactions: \$redactionsAppliedCount, violations: \$privacyViolationsCount)';
}
