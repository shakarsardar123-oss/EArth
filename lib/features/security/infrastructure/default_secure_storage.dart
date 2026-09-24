/// default_secure_storage.dart
/// AURA Assistant – Step 19: Security & Privacy Hardening
///
/// Default infrastructure implementation of SecureStorageService.
/// Backed by flutter_secure_storage (Android Keystore / iOS Keychain),
/// so data is encrypted at rest by the OS and survives app restarts.
///
/// FAIL CLOSED: if secure storage is unavailable, all operations fail
/// and reads return nothing (never expose unencrypted fallback).
library;

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:texo/core/errors/result.dart';
import '../application/secure_storage_service.dart';
import '../domain/models/security_failure.dart';

/// Prefix used to namespace metadata entries so they never collide with
/// real data keys stored under the same [FlutterSecureStorage] instance.
const String _metaPrefix = '__aura_secure_meta__:';

class DefaultSecureStorage implements SecureStorageService {
  final FlutterSecureStorage _storage;

  /// Test-only override to simulate storage becoming unavailable without
  /// needing to fake the platform channel. Defaults to null (real check).
  bool? _forcedAvailable;

  DefaultSecureStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<bool> get isAvailable async {
    if (_forcedAvailable != null) return _forcedAvailable!;
    try {
      // Cheap round-trip to confirm the platform channel is functional.
      // Does not touch real caller data (uses its own reserved key).
      const probeKey = '${_metaPrefix}availability_probe';
      await _storage.write(key: probeKey, value: '1');
      await _storage.delete(key: probeKey);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Simulate storage becoming unavailable (for testing fail-closed).
  /// Pass null to go back to the real availability check.
  void setAvailable(bool? available) => _forcedAvailable = available;

  @override
  Future<SecurityResult<void>> write(
    String key,
    String value, {
    SecureStorageDataType dataType = SecureStorageDataType.unknown,
  }) async {
    if (!await isAvailable) {
      return SecurityFailure.secureStorageFailed(
        action: 'write',
        cause: 'Secure storage is not available',
      ).asFailure<void>();
    }

    if (key.isEmpty) {
      return SecurityFailure.secureStorageFailed(
        action: 'write',
        cause: 'Key must not be empty',
      ).asFailure<void>();
    }

    try {
      await _storage.write(key: key, value: value);
      await _storage.write(
        key: _metaKey(key),
        value: jsonEncode({
          'dataType': dataType.name,
          'writtenAt': DateTime.now().toIso8601String(),
        }),
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
    if (!await isAvailable) {
      // FAIL CLOSED: return failure, never expose raw data
      return SecurityFailure.secureStorageFailed(
        action: 'read',
        cause: 'Secure storage is not available',
      ).asFailure<String>();
    }

    try {
      final value = await _storage.read(key: key);
      if (value == null) {
        return SecurityFailure.secureStorageFailed(
          action: 'read',
          cause: 'Key not found: $key',
        ).asFailure<String>();
      }
      return Success(value);
    } catch (e) {
      return SecurityFailure.secureStorageFailed(
        action: 'read',
        cause: 'Failed to read from secure storage',
      ).asFailure<String>();
    }
  }

  @override
  Future<SecurityResult<bool>> delete(String key) async {
    if (!await isAvailable) {
      return SecurityFailure.secureStorageFailed(
        action: 'delete',
        cause: 'Secure storage is not available',
      ).asFailure<bool>();
    }

    try {
      final existed = await _storage.containsKey(key: key);
      await _storage.delete(key: key);
      await _storage.delete(key: _metaKey(key));
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
    if (!await isAvailable) {
      // FAIL CLOSED: when unavailable, deny existence knowledge
      return SecurityFailure.secureStorageFailed(
        action: 'exists',
        cause: 'Secure storage is not available',
      ).asFailure<bool>();
    }

    try {
      return Success(await _storage.containsKey(key: key));
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
    if (!await isAvailable) {
      return SecurityFailure.secureStorageFailed(
        action: 'getMetadata',
        cause: 'Secure storage is not available',
      ).asFailure<SecureStorageMetadata>();
    }

    try {
      final rawMeta = await _storage.read(key: _metaKey(key));
      if (rawMeta == null) {
        return SecurityFailure.secureStorageFailed(
          action: 'getMetadata',
          cause: 'Key not found: $key',
        ).asFailure<SecureStorageMetadata>();
      }

      final meta = jsonDecode(rawMeta) as Map<String, dynamic>;
      final dataType = SecureStorageDataType.values.firstWhere(
        (t) => t.name == meta['dataType'],
        orElse: () => SecureStorageDataType.unknown,
      );

      return Success(SecureStorageMetadata(
        dataType: dataType,
        key: key,
        writtenAt: DateTime.tryParse(meta['writtenAt'] as String? ?? ''),
        isEncrypted: true,
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
    if (!await isAvailable) {
      return SecurityFailure.secureStorageFailed(
        action: 'listKeys',
        cause: 'Secure storage is not available',
      ).asFailure<List<String>>();
    }

    try {
      final all = await _storage.readAll();
      final dataKeys = all.keys.where((k) => !k.startsWith(_metaPrefix));

      if (dataType == null) {
        return Success(dataKeys.toList());
      }

      final filtered = <String>[];
      for (final key in dataKeys) {
        final rawMeta = all[_metaKey(key)];
        if (rawMeta == null) continue;
        try {
          final meta = jsonDecode(rawMeta) as Map<String, dynamic>;
          if (meta['dataType'] == dataType.name) {
            filtered.add(key);
          }
        } catch (_) {
          // Skip entries with unreadable metadata rather than fail the
          // whole listing.
          continue;
        }
      }
      return Success(filtered);
    } catch (_) {
      // FAIL CLOSED: return empty on error
      return Success([]);
    }
  }

  @override
  Future<SecurityResult<int>> clearAll() async {
    if (!await isAvailable) {
      return SecurityFailure.secureStorageFailed(
        action: 'clearAll',
        cause: 'Secure storage is not available',
      ).asFailure<int>();
    }

    try {
      final all = await _storage.readAll();
      final count = all.keys.where((k) => !k.startsWith(_metaPrefix)).length;
      await _storage.deleteAll();
      return Success(count);
    } catch (_) {
      return SecurityFailure.secureStorageFailed(
        action: 'clearAll',
        cause: 'Failed to clear secure storage',
      ).asFailure<int>();
    }
  }

  // ─── Private helpers ─────────────────────────────────────────────

  String _metaKey(String key) => '$_metaPrefix$key';
}
