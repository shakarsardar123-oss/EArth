import '../../core/errors/result.dart';
import '../../core/errors/failures.dart';

/// Abstraction over local storage with secure vs. normal distinction.
///
/// Phase 1 uses SharedPreferences for normal storage. Phase 2+
/// will add flutter_secure_storage for sensitive data.
abstract class StorageService {
  // ── Normal (non-encrypted) storage ────────────────────────────

  /// Reads a string from normal storage.
  Future<Result<String?, StorageFailure>> getString(String key);

  /// Writes a string to normal storage.
  Future<Result<bool, StorageFailure>> setString(String key, String value);

  /// Reads a bool from normal storage.
  Future<Result<bool?, StorageFailure>> getBool(String key);

  /// Writes a bool to normal storage.
  Future<Result<bool, StorageFailure>> setBool(String key, bool value);

  /// Removes a key from normal storage.
  Future<Result<bool, StorageFailure>> remove(String key);

  // ── Secure (encrypted) storage ────────────────────────────────

  /// Reads a string from secure storage.
  Future<Result<String?, StorageFailure>> getSecureString(String key);

  /// Writes a string to secure storage.
  Future<Result<bool, StorageFailure>> setSecureString(String key, String value);

  /// Removes a key from secure storage.
  Future<Result<bool, StorageFailure>> removeSecure(String key);

  // ── Bulk operations ──────────────────────────────────────────

  /// Clears all normal-storage keys.
  Future<Result<bool, StorageFailure>> clearNormal();

  /// Clears all secure-storage keys.
  Future<Result<bool, StorageFailure>> clearSecure();
}
