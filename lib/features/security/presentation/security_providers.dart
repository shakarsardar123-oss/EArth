/// security_providers.dart
/// AURA Assistant – Step 19: Security & Privacy Hardening
///
/// Riverpod provider definitions for the security feature.
/// Follows project convention: abstract ProviderNames class +
/// concrete final provider instances with name: parameter.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/agent_security_service.dart';
import '../application/permission_security_service.dart';
import '../application/provider_privacy_service.dart';
import '../application/screen_privacy_service.dart';
import '../application/secure_storage_service.dart';
import '../application/security_controller.dart';
import '../application/security_policy.dart';
import '../application/voice_privacy_service.dart';
import '../domain/models/security_config.dart';
import '../domain/models/security_state.dart';
import '../domain/services/secret_scanner_service.dart';
import '../domain/services/secure_logging_service.dart';
import '../domain/services/sensitive_data_redactor.dart';
import '../domain/services/security_audit_service.dart';
import '../infrastructure/default_secret_scanner.dart';
import '../infrastructure/default_secure_logger.dart';
import '../infrastructure/default_secure_storage.dart';
import '../infrastructure/default_security_audit.dart';
import '../infrastructure/default_sensitive_data_redactor.dart';
import 'security_state_notifier.dart';

/// Abstract class defining provider names for the security feature.
abstract class SecurityProviderNames {
  static const String secretScanner = 'security_secret_scanner';
  static const Type secretScannerType = SecretScannerService;

  static const String secureLogger = 'security_secure_logger';
  static const Type secureLoggerType = SecureLoggingService;

  static const String sensitiveDataRedactor =
      'security_sensitive_data_redactor';
  static const Type sensitiveDataRedactorType = SensitiveDataRedactor;

  static const String securityAudit = 'security_security_audit';
  static const Type securityAuditType = SecurityAuditService;

  static const String secureStorage = 'security_secure_storage';
  static const Type secureStorageType = SecureStorageService;

  static const String securityPolicy = 'security_security_policy';
  static const Type securityPolicyType = SecurityPolicy;

  static const String securityController =
      'security_security_controller';
  static const Type securityControllerType = SecurityController;

  static const String agentSecurity = 'security_agent_security';
  static const Type agentSecurityType = AgentSecurityService;

  static const String providerPrivacy = 'security_provider_privacy';
  static const Type providerPrivacyType = ProviderPrivacyService;

  static const String screenPrivacy = 'security_screen_privacy';
  static const Type screenPrivacyType = ScreenPrivacyService;

  static const String voicePrivacy = 'security_voice_privacy';
  static const Type voicePrivacyType = VoicePrivacyService;

  static const String permissionSecurity =
      'security_permission_security';
  static const Type permissionSecurityType = PermissionSecurityService;

  static const String securityStateNotifier =
      'security_state_notifier';
  static const Type securityStateNotifierType =
      SecurityStateNotifier;

  static const String securityConfig = 'security_config';
  static const Type securityConfigType = SecurityConfig;

  static const String securityState = 'security_state';
  static const Type securityStateType = SecurityState;
}

/// Secret scanner provider.
final securitySecretScannerProvider = Provider<SecretScannerService>(
  name: SecurityProviderNames.secretScanner,
  (ref) => DefaultSecretScanner(),
);

/// Sensitive data redactor provider.
final securitySensitiveDataRedactorProvider =
    Provider<SensitiveDataRedactor>(
  name: SecurityProviderNames.sensitiveDataRedactor,
  (ref) => DefaultSensitiveDataRedactor(),
);

/// Secure logging service provider.
final securitySecureLoggerProvider = Provider<SecureLoggingService>(
  name: SecurityProviderNames.secureLogger,
  (ref) => DefaultSecureLogger(
    redactor: ref.watch(securitySensitiveDataRedactorProvider),
  ),
);

/// Security audit service provider.
final securityAuditServiceProvider =
    Provider<SecurityAuditService>(
  name: SecurityProviderNames.securityAudit,
  (ref) => DefaultSecurityAuditService(
    config: ref.watch(securityConfigProvider),
  ),
);

/// Secure storage provider.
final securitySecureStorageProvider =
    Provider<SecureStorageService>(
  name: SecurityProviderNames.secureStorage,
  (ref) => DefaultSecureStorage(),
);

/// Security config provider.
final securityConfigProvider = StateProvider<SecurityConfig>(
  name: SecurityProviderNames.securityConfig,
  (ref) => const SecurityConfig(),
);

/// Security state notifier provider.
final securityStateNotifierProvider =
    StateNotifierProvider<SecurityStateNotifier, SecurityState>(
  name: SecurityProviderNames.securityStateNotifier,
  (ref) => SecurityStateNotifier(
    config: ref.watch(securityConfigProvider),
    scanner: ref.watch(securitySecretScannerProvider),
    redactor: ref.watch(securitySensitiveDataRedactorProvider),
    auditService: ref.watch(securityAuditServiceProvider),
    logger: ref.watch(securitySecureLoggerProvider),
    storage: ref.watch(securitySecureStorageProvider),
  ),
);

/// Security state provider (convenience accessor).
final securityStateProvider = Provider<SecurityState>(
  name: SecurityProviderNames.securityState,
  (ref) => ref.watch(securityStateNotifierProvider),
);
