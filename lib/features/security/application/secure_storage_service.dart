/// secure_storage_service.dart
/// AURA Assistant – Step 19: Security & Privacy Hardening
///
/// Application service for secure local storage.
/// All data stored through this service is encrypted at rest.
///
/// FAIL CLOSED: if storage is unavailable, all write operations fail
/// and read operations return empty/default values (never expose
/// unencrypted data).
library;

import 'package:aura_assistant/core/errors/result.dart';
import '../domain/models/security_failure.dart';

/// The type of data being stored.
enum SecureStorageDataType {
  /// Security configuration.
  securityConfig,

  /// Audit log entries.
  auditLog,

  /// Redaction rules.
  redactionRules,

  /// Security state.
  securityState,

  /// Custom allow/deny lists.
  accessControlLists,

  /// Provider privacy profiles.
  providerProfiles,

  /// Sensitive app packages.
  sensitiveAppPackages,

  /// Encryption keys (meta only — never store raw keys).
  encryptionKeyMeta,

  /// Unknown — FAIL CLOSED: treated as security config (most restrictive).
  unknown,
}

/// Metadata for a stored item.
class SecureStorageMetadata {
  /// The data type.
  final SecureStorageDataType dataType;

  /// The key under which the data is stored.
  final String key;

  /// When the data was written.
  final DateTime? writtenAt;

  /// When the data expires (if applicable).
  final DateTime? expiresAt;

  /// Whether the data is currently encrypted.
  final bool isEncrypted;

  const SecureStorageMetadata({
    required this.dataType,
    required this.key,
    this.writtenAt,
    this.expiresAt,
    this.isEncrypted = true,
  });

  /// FAIL CLOSED: if not marked encrypted, treat as compromised.
  bool get isCompromised => !isEncrypted;
}

/// Abstract application service for secure storage.
///
/// All operations:
/// - Encrypt data at rest.
/// - Verify integrity on read.
/// - FAIL CLOSED: if storage unavailable, deny all operations.
abstract class SecureStorageService {
  /// Write encrypted data to storage.
  Future<SecurityResult<void>> write(
    String key,
    String value, {
    SecureStorageDataType dataType = SecureStorageDataType.unknown,
  });

  /// Read and decrypt data from storage.
  ///
  /// FAIL CLOSED: if decryption fails, returns failure (not raw data).
  Future<SecurityResult<String>> read(
    String key, {
    SecureStorageDataType dataType = SecureStorageDataType.unknown,
  });

  /// Delete data from storage.
  Future<SecurityResult<bool>> delete(String key);

  /// Check if a key exists in storage.
  Future<SecurityResult<bool>> exists(String key);

  /// Get metadata for a stored key.
  Future<SecurityResult<SecureStorageMetadata>> getMetadata(String key);

  /// List all keys of a given data type.
  Future<SecurityResult<List<String>>> listKeys({
    SecureStorageDataType? dataType,
  });

  /// Clear all stored data (factory reset for security).
  Future<SecurityResult<int>> clearAll();

  /// Whether secure storage is available and functional.
  Future<bool> get isAvailable;
}
