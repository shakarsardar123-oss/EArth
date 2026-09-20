import '../../domain/entities/app_config.dart';
import '../../domain/repositories/app_config_repository.dart';
import '../datasources/local_storage_data_source.dart';
import '../models/app_config_model.dart';

/// Concrete implementation of [AppConfigRepository] that delegates
/// persistence to [LocalStorageDataSource].
class AppConfigRepositoryImpl implements AppConfigRepository {
  AppConfigRepositoryImpl(this._dataSource);

  final LocalStorageDataSource _dataSource;

  @override
  AppConfig getAppConfig() {
    return AppConfigModel(
      themeMode: _dataSource.themeMode,
      localeCode: _dataSource.localeCode,
      agentId: _dataSource.activeAgentId,
      onboardingCompleted: _dataSource.onboardingCompleted,
    ).toEntity();
  }

  @override
  Future<void> saveAppConfig(AppConfig config) async {
    final model = AppConfigModel.fromEntity(config);
    await _dataSource.setThemeMode(model.themeMode);
    await _dataSource.setLocaleCode(model.localeCode);
    await _dataSource.setActiveAgentId(model.agentId);
    await _dataSource.setOnboardingCompleted(model.onboardingCompleted);
  }

  @override
  Future<void> setActiveAgentId(String agentId) async {
    await _dataSource.setActiveAgentId(agentId);
  }

  @override
  String getActiveAgentId() => _dataSource.activeAgentId;
}
