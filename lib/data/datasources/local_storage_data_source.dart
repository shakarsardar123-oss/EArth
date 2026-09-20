import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/result.dart';
import '../../core/errors/failures.dart';

/// Abstraction over local key-value storage (backed by SharedPreferences).
///
/// Phase 1 provides simple get/set operations. Future phases may
/// add encrypted storage, object box, or other backends.
class LocalStorageDataSource {
  LocalStorageDataSource(this._prefs);

  final SharedPreferences _prefs;

  // ── Generic get / set ───────────────────────────────────────────

  String? getString(String key) => _prefs.getString(key);

  Future<Result<bool, StorageFailure>> setString(String key, String value) async {
    try {
      final ok = await _prefs.setString(key, value);
      return Result.success(ok);
    } catch (e) {
      return Result.failure(StorageFailure(message: 'Failed to set string: $e'));
    }
  }

  bool? getBool(String key) => _prefs.getBool(key);

  Future<Result<bool, StorageFailure>> setBool(String key, bool value) async {
    try {
      final ok = await _prefs.setBool(key, value);
      return Result.success(ok);
    } catch (e) {
      return Result.failure(StorageFailure(message: 'Failed to set bool: $e'));
    }
  }

  int? getInt(String key) => _prefs.getInt(key);

  Future<Result<bool, StorageFailure>> setInt(String key, int value) async {
    try {
      final ok = await _prefs.setInt(key, value);
      return Result.success(ok);
    } catch (e) {
      return Result.failure(StorageFailure(message: 'Failed to set int: $e'));
    }
  }

  // ── App-specific convenience methods ────────────────────────────

  String get themeMode => getString(AppConstants.themeKey) ?? 'dark';

  Future<Result<bool, StorageFailure>> setThemeMode(String mode) =>
      setString(AppConstants.themeKey, mode);

  String get localeCode => getString(AppConstants.localeKey) ?? 'ku';

  Future<Result<bool, StorageFailure>> setLocaleCode(String code) =>
      setString(AppConstants.localeKey, code);

  bool get onboardingCompleted => getBool(AppConstants.onboardingKey) ?? false;

  Future<Result<bool, StorageFailure>> setOnboardingCompleted(bool value) =>
      setBool(AppConstants.onboardingKey, value);

  String get activeAgentId => getString(AppConstants.activeAgentKey) ?? 'aura';

  Future<Result<bool, StorageFailure>> setActiveAgentId(String id) =>
      setString(AppConstants.activeAgentKey, id);

  // ── Remove / Clear ──────────────────────────────────────────────

  Future<Result<bool, StorageFailure>> remove(String key) async {
    try {
      final ok = await _prefs.remove(key);
      return Result.success(ok);
    } catch (e) {
      return Result.failure(StorageFailure(message: 'Failed to remove key: $e'));
    }
  }

  Future<Result<bool, StorageFailure>> clear() async {
    try {
      final ok = await _prefs.clear();
      return Result.success(ok);
    } catch (e) {
      return Result.failure(StorageFailure(message: 'Failed to clear storage: $e'));
    }
  }
}
