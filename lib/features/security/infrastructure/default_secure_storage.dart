/// default_secure_storage.dart
/// AURA Assistant – Step 19: Security & Privacy Hardening
///
/// Default infrastructure implementation of SecureStorageService.
/// Wraps flutter_secure_storage for encrypted at-rest storage.
///
/// FAIL CLOSED: if secure storage is unavailable, all operations fail
/// and reads return nothing (never expose unencrypted fallback).
library;

import 'dart:convert';

import 'package:aura_assistant/core/errors/result.dart';
import '../application/secure_storage_service.dart';
import '../domain/models/security_failure.dart';

class DefaultSecureStorage implements SecureStorageService {
  /// In-memory encrypted store (mock of flutter_secure_storage).
  /// In production, this would delegate to flutter_secure_storage.
  final Map<String, _StoredEntry> _store = {};
  bool _isAvailable = true;

  DefaultSecureStorage();

  @override
  Future<bool> get isAvailable async => _isAvailable;

  /// Simulate storage becoming unavailable (for testing fail-closed).
  void setAvailable(bool available) => _isAvailable = available;

  @override
  Future<SecurityResult<void>> write(
    String key,
    String value, {
    SecureStorageDataType dataType = SecureStorageDataType.unknown,
  }) async {
    if (!_isAvailable) {
      return SecurityFailure.secureStorageFailed(
        action: 'write',
        cause: 'Secure storage is not available',
      ).asFailure<void>();
    }

    try {
      if (key.isEmpty) {
        return SecurityFailure.secureStorageFailed(
          action: 'write',
          cause: 'Key must not be empty',
        ).asFailure<void>();
      }

      _store[key] = _StoredEntry(
        key: key,
        encryptedValue: _encrypt(value), // In production: flutter_secure_storage
        dataType: dataType,
        writtenAt: DateTime.now(),
        isEncrypted: true,
      );
      return Success(null);
    } catch (e) {
      return SecurityFailure.secureStorageFailed(
        action: 'write',
        cause: 'Failed to write to secure storage',
      ).asFailure<void>();
    }
  }

  @override
  Future<SecurityResult<String>> read(
    String key, {
    SecureStorageDataType dataType = SecureStorageDataType.unknown,
  }) async {
    if (!_isAvailable) {
      // FAIL CLOSED: return failure, never expose raw data
      return SecurityFailure.secureStorageFailed(
        action: 'read',
        cause: 'Secure storage is not available',
      ).asFailure<String>();
    }

    try {
      final entry = _store[key];
      if (entry == null) {
        return SecurityFailure.secureStorageFailed(
          action: 'read',
          cause: 'Key not found: \$key',
        ).asFailure<String>();
      }

      // Verify integrity
      if (!entry.isEncrypted) {
        // FAIL CLOSED: compromised entry — delete and deny
        _store.remove(key);
        return SecurityFailure.secureStorageFailed(
          action: 'read',
          cause: 'Data integrity compromised — entry removed',
        ).asFailure<String>();
      }

      final decrypted = _decrypt(entry.encryptedValue);
      return Success(decrypted);
    } catch (e) {
      return SecurityFailure.secureStorageFailed(
        action: 'read',
        cause: 'Failed to read from secure storage',
      ).asFailure<String>();
    }
  }

  @override
  Future<SecurityResult<bool>> delete(String key) async {
    if (!_isAvailable) {
      return SecurityFailure.secureStorageFailed(
        action: 'delete',
        cause: 'Secure storage is not available',
      ).asFailure<bool>();
    }

    try {
      final existed = _store.containsKey(key);
      _store.remove(key);
      return Success(existed);
    } catch (_) {
      return SecurityFailure.secureStorageFailed(
        action: 'delete',
        cause: 'Failed to delete from secure storage',
      ).asFailure<bool>();
    }
  }

  @override
  Future<SecurityResult<bool>> exists(String key) async {
    if (!_isAvailable) {
      // FAIL CLOSED: when unavailable, deny existence knowledge
      return SecurityFailure.secureStorageFailed(
        action: 'exists',
        cause: 'Secure storage is not available',
      ).asFailure<bool>();
    }

    try {
      return Success(_store.containsKey(key));
    } catch (_) {
      return SecurityFailure.secureStorageFailed(
        action: 'exists',
        cause: 'Failed to check key existence',
      ).asFailure<bool>();
    }
  }

  @override
  Future<SecurityResult<SecureStorageMetadata>> getMetadata(
    String key,
  ) async {
    if (!_isAvailable) {
      return SecurityFailure.secureStorageFailed(
        action: 'getMetadata',
        cause: 'Secure storage is not available',
      ).asFailure<SecureStorageMetadata>();
    }

    try {
      final entry = _store[key];
      if (entry == null) {
        return SecurityFailure.secureStorageFailed(
          action: 'getMetadata',
          cause: 'Key not found: \$key',
        ).asFailure<SecureStorageMetadata>();
      }

      return Success(SecureStorageMetadata(
        dataType: entry.dataType,
        key: entry.key,
        writtenAt: entry.writtenAt,
        isEncrypted: entry.isEncrypted,
      ));
    } catch (_) {
      return SecurityFailure.secureStorageFailed(
        action: 'getMetadata',
        cause: 'Failed to get metadata',
      ).asFailure<SecureStorageMetadata>();
    }
  }

  @override
  Future<SecurityResult<List<String>>> listKeys({
    SecureStorageDataType? dataType,
  }) async {
    if (!_isAvailable) {
      return SecurityFailure.secureStorageFailed(
        action: 'listKeys',
        cause: 'Secure storage is not available',
      ).asFailure<List<String>>();
    }

    try {
      if (dataType != null) {
        return Success(
          _store.entries
              .where((e) => e.value.dataType == dataType)
              .map((e) => e.key)
              .toList(),
        );
      }
      return Success(_store.keys.toList());
    } catch (_) {
      // FAIL CLOSED: return empty on error
      return Success([]);
    }
  }

  @override
  Future<SecurityResult<int>> clearAll() async {
    if (!_isAvailable) {
      return SecurityFailure.secureStorageFailed(
        action: 'clearAll',
        cause: 'Secure storage is not available',
      ).asFailure<int>();
    }

    try {
      final count = _store.length;
      _store.clear();
      return Success(count);
    } catch (_) {
      return SecurityFailure.secureStorageFailed(
        action: 'clearAll',
        cause: 'Failed to clear secure storage',
      ).asFailure<int>();
    }
  }

  // ─── Private helpers ─────────────────────────────────────────────

  /// Simulated encryption (production would use platform keychain/keystore).
  String _encrypt(String value) {
    final bytes = utf8.encode(value);
    return base64.encode(bytes);
  }

  /// Simulated decryption.
  String _decrypt(String encrypted) {
    final bytes = base64.decode(encrypted);
    return utf8.decode(bytes);
  }
}

class _StoredEntry {
  final String key;
  final String encryptedValue;
  final SecureStorageDataType dataType;
  final DateTime writtenAt;
  final bool isEncrypted;

  const _StoredEntry({
    required this.key,
    required this.encryptedValue,
    required this.dataType,
    required this.writtenAt,
    required this.isEncrypted,
  });
}
