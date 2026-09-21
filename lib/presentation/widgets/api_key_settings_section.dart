/// api_key_settings_section.dart
/// AURA Assistant – P1+P2 Fix: Provider-Agnostic API Settings
///
/// REWRITTEN: No longer casts to OpenAIProvider.
/// - Uses provider-agnostic AIProvider interface for API key storage.
/// - Routes gemini config to geminiProvider, OpenAI config to OpenAIProvider.
/// - Supports both gemini and OpenAI key storage.
/// - Test connection adapted per provider (gemini: native API, OpenAI: models endpoint).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/ai/connection_type.dart';
import '../../core/ai/provider_registry.dart';
import '../../core/ai/gemini_provider.dart'
    show kDefaultGeminiChatModel, GeminiProvider, kGeminiDefaultBaseUrl;
import '../../core/ai/auto_model_service.dart'
    show AutoModelService, AutoModelSelectionResult;
import '../../core/ai/ai_error_presenter.dart' show AIErrorPresenter;
import '../../core/ai/model_discovery.dart' show ModelSelector;
import '../../l10n/app_localizations.dart' show S;
import '../../services/ai/ai_provider.dart' show AIProvider;
import '../providers/app_providers.dart'
    show
        aiConnectionStorageProvider,
        geminiProviderProvider,
        openaiProviderProvider,
        agentConfigProvider;
import 'glass_dialog.dart';

/// API key / connection settings section — provider-agnostic glass design.
///
/// Features:
/// - Provider picker dropdown (gemini, OpenAI, Custom)
/// - Dynamic model list based on selected provider
/// - Editable base URL (pre-filled from preset, editable)
/// - API key field with show/hide
/// - Save/test buttons wired to provider-specific storage
/// - No provider-specific casts — works with geminiProvider and OpenAIProvider
class ApiKeySettingsSection extends ConsumerStatefulWidget {
  const ApiKeySettingsSection({super.key});

  @override
  ConsumerState<ApiKeySettingsSection> createState() =>
      _ApiKeySettingsSectionState();
}

class _ApiKeySettingsSectionState extends ConsumerState<ApiKeySettingsSection> {
  final _apiKeyController = TextEditingController();
  final _baseUrlController = TextEditingController();
  final _customModelController = TextEditingController();
  String _selectedModel = kDefaultGeminiChatModel;
  ConnectionType _selectedProviderType = ConnectionType.gemini;
  ProviderPreset? _selectedPreset;
  bool _obscureApiKey = true;
  bool _isSaving = false;
  bool _isTesting = false;
  String? _saveStatus;
  String? _testResult;
  /// Whether the last test finished successfully (drives the status color,
  /// since the localized success message has no ✓ marker).
  bool _testSucceeded = false;
  bool _isLoaded = false;
  /// True once the user explicitly picks a model in the UI, so [_saveConfig]
  /// persists it as a USER selection (never overwritten by AUTO recovery).
  bool _modelUserChosen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadConfig());
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _customModelController.dispose();
    super.dispose();
  }

  /// Gets the currently active AIProvider based on selected type.
  AIProvider get _currentProvider {
    switch (_selectedProviderType) {
      case ConnectionType.gemini:
        return ref.read(geminiProviderProvider);
      case ConnectionType.openaiCompatible:
      case ConnectionType.customOpenAI:
        return ref.read(openaiProviderProvider);
    }
  }

  Future<void> _loadConfig() async {
    try {
      final connectionStorage = ref.read(aiConnectionStorageProvider);
      final provider = _currentProvider;

      final apiKey = await provider.getApiKey();
      final baseUrl = await connectionStorage.getBaseUrl();
      final model = connectionStorage.getModel();
      final connectionType = connectionStorage.getConnectionType();

      final preset = ProviderRegistry.presetForType(connectionType) ??
          ProviderRegistry.defaultPreset;

      if (mounted) {
        _apiKeyController.text = apiKey ?? '';
        _baseUrlController.text = baseUrl;
        _selectedProviderType = connectionType;
        _selectedPreset = preset;

        // Set model: if it's in the preset list, select it; otherwise use custom
        if (preset.supportedModels.toSet().toList().contains(model)) {
          _selectedModel = model;
        } else if (model.isNotEmpty) {
          _selectedModel = model;
          _customModelController.text = model;
        } else {
          _selectedModel = preset.defaultModel;
        }

        _isLoaded = true;
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        _isLoaded = true;
        setState(() {});
      }
    }
  }

  Future<void> _saveConfig() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
      _saveStatus = null;
    });

    try {
      final connectionStorage = ref.read(aiConnectionStorageProvider);
      final provider = _currentProvider;

      // Save API key via the provider's own secure storage
      final apiKey = _apiKeyController.text.trim();
      if (apiKey.isNotEmpty) {
        await provider.setApiKey(apiKey);
      }

      // Save base URL. Validate FIRST via the provider (enforces HTTPS +
      // a real host) and only mirror it into AIConnectionStorage once that
      // succeeds, so an invalid URL can never reach secure storage. An
      // empty field is treated as an explicit reset back to the built-in
      // default rather than silently keeping whatever was saved before.
      final baseUrl = _baseUrlController.text.trim();
      if (baseUrl.isNotEmpty) {
        try {
          await provider.setBaseUrl(baseUrl);
          await connectionStorage.setBaseUrl(baseUrl, _selectedProviderType);
        } catch (e) {
          if (mounted) {
            setState(() {
              _isSaving = false;
              _saveStatus = 'هەڵە، $e';
            });
          }
          return;
        }
      } else {
        await connectionStorage.clearBaseUrl(_selectedProviderType);
        if (provider is GeminiProvider) {
          await provider.clearBaseUrl();
        }
      }

      // Save connection type
      connectionStorage.setConnectionType(_selectedProviderType);

      // Save model. When the user explicitly picked a model in the UI we
      // persist it as a USER selection so AUTO recovery never overwrites it;
      // otherwise keep it as the existing (possibly AUTO) selection.
      final model = _selectedPreset?.allowsCustomModel == true &&
              _customModelController.text.trim().isNotEmpty
          ? _customModelController.text.trim()
          : _selectedModel;
      if (_modelUserChosen) {
        await connectionStorage.setUserSelectedModel(model);
      } else {
        connectionStorage.setModel(model);
      }

      // Update agent config
      final currentConfig = ref.read(agentConfigProvider);
      ref.read(agentConfigProvider.notifier).state =
          currentConfig.copyWith(modelId: model);

      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveStatus = 'پاشەکەوتکرا ✓';
        });

        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _saveStatus = null);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveStatus = 'هەڵە، $e';
        });
      }
    }
  }

  Future<void> _testConnection() async {
    if (_isTesting) return;

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final l10n = S.of(context);
    try {
      final connectionStorage = ref.read(aiConnectionStorageProvider);
      final provider = _currentProvider;

      // Persist the entered key + base URL + connection type FIRST so the
      // provider's discovery uses the values under test.
      final apiKey = _apiKeyController.text.trim();
      if (apiKey.isNotEmpty) {
        await provider.setApiKey(apiKey);
      }
      final baseUrl = _baseUrlController.text.trim();
      if (baseUrl.isNotEmpty) {
        await provider.setBaseUrl(baseUrl);
        await connectionStorage.setBaseUrl(baseUrl, _selectedProviderType);
      }
      connectionStorage.setConnectionType(_selectedProviderType);

      final storedKey = await provider.getApiKey();
      if (storedKey == null || storedKey.isEmpty) {
        setState(() {
          _isTesting = false;
          _testResult = l10n.aiErrorMissingKey;
        });
        return;
      }

      // Discover the available models for this key and auto-select a
      // compatible chat model — the user never types a model id by hand.
      final service = AutoModelService(storage: connectionStorage);
      final preferenceOrder = _selectedProviderType == ConnectionType.gemini
          ? ModelSelector.geminiPreferenceOrder
          : ModelSelector.openAIPreferenceOrder;
      final AutoModelSelectionResult result = await service.discoverAndSelect(
        provider: provider,
        preferenceOrder: preferenceOrder,
        verifyWithGeneration: true,
      );

      if (!mounted) return;
      if (result.success) {
        final model = result.selectedModel ?? connectionStorage.getModel();
        // Reflect the auto-selected model in the UI + agent config.
        setState(() {
          _isTesting = false;
          _testSucceeded = true;
          _selectedModel = model;
          _testResult = l10n.aiConnectionSuccessModel(model);
        });
        final currentConfig = ref.read(agentConfigProvider);
        ref.read(agentConfigProvider.notifier).state =
            currentConfig.copyWith(modelId: model);
      } else {
        setState(() {
          _isTesting = false;
          _testSucceeded = false;
          _testResult = AIErrorPresenter.messageForCategory(
            result.errorCategory!,
            l10n,
          );
        });
      }
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) setState(() => _testResult = null);
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTesting = false;
          _testSucceeded = false;
          _testResult = AIErrorPresenter.present(e, l10n);
        });
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) setState(() => _testResult = null);
        });
      }
    }
  }

  void _onProviderChanged(ProviderPreset preset) {
    setState(() {
      _selectedPreset = preset;
      _selectedProviderType = preset.connectionType;
      _baseUrlController.text = preset.defaultBaseUrl;
      _selectedModel = preset.defaultModel;
      _customModelController.clear();
      _modelUserChosen = false;
      _saveStatus = null;
      _testResult = null;
      _testSucceeded = false;
    });
  }

  List<String> get _currentModelOptions {
    if (_selectedPreset == null) return [];
    final models = _selectedPreset!.supportedModels.toSet().toList();
    if (_selectedPreset!.allowsCustomModel) {
      models.add('custom');
    }
    return models;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Provider Picker ──
        const _FieldLabel(label: 'دابینکەری AI'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.glassInputBackground,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.glassBorder, width: 0.5),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<ProviderPreset>(
              value: _selectedPreset ?? ProviderRegistry.defaultPreset,
              isExpanded: true,
              icon: Icon(Icons.arrow_drop_down, color: AppColors.cyan),
              style: TextStyle(
                fontSize: 14,
                color: AppColors.onBackground,
              ),
              dropdownColor: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              items: ProviderRegistry.presets
                  .map((preset) => DropdownMenuItem(
                        value: preset,
                        child: Text(
                          '${preset.icon} ${preset.displayName}',
                          textDirection: TextDirection.ltr,
                        ),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) _onProviderChanged(value);
              },
            ),
          ),
        ),

        const SizedBox(height: 16),

        // ── API Key Field ──
        const _FieldLabel(label: 'کلیلی API'),
        const SizedBox(height: 8),
        GlassTextField(
          controller: _apiKeyController,
          obscureText: _obscureApiKey,
          hint: _selectedProviderType == ConnectionType.gemini
              ? 'AIza...'
              : 'sk-...',
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  _obscureApiKey
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 18,
                ),
                color: AppColors.hint,
                onPressed: () {
                  setState(() => _obscureApiKey = !_obscureApiKey);
                },
              ),
              IconButton(
                icon: const Icon(Icons.copy_outlined, size: 18),
                color: AppColors.hint,
                onPressed: () {
                  final text = _apiKeyController.text;
                  if (text.isNotEmpty) {
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('کوپی کرا'),
                        duration: const Duration(seconds: 1),
                        backgroundColor: AppColors.violet,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          onChanged: (_) => _clearSaveStatus(),
        ),

        const SizedBox(height: 16),

        // ── Base URL Field ──
        const _FieldLabel(label: 'ناونیشانی بنەڕەتی'),
        const SizedBox(height: 8),
        GlassTextField(
          controller: _baseUrlController,
          hint: _selectedProviderType == ConnectionType.gemini
              ? kGeminiDefaultBaseUrl
              : 'https://api.openai.com/v1',
          onChanged: (_) => _clearSaveStatus(),
        ),

        const SizedBox(height: 16),

        // ── Model Dropdown / Custom Input ──
        const _FieldLabel(label: 'مۆدێل'),
        const SizedBox(height: 8),
        if (_currentModelOptions.isNotEmpty &&
            !(_selectedPreset?.allowsCustomModel == true &&
                _selectedModel == 'custom'))
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.glassInputBackground,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.glassBorder, width: 0.5),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _currentModelOptions.contains(_selectedModel)
                    ? _selectedModel
                    : null,
                isExpanded: true,
                icon: Icon(Icons.arrow_drop_down, color: AppColors.cyan),
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'monospace',
                  color: AppColors.onBackground,
                ),
                dropdownColor: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                items: _currentModelOptions
                    .map((model) => DropdownMenuItem(
                          value: model,
                          child: Text(
                            model == 'custom' ? 'مۆدێلی تایبەت...' : model,
                            textDirection: TextDirection.ltr,
                          ),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedModel = value;
                      _customModelController.clear();
                      _modelUserChosen = value != 'custom';
                      _saveStatus = null;
                    });
                  }
                },
              ),
            ),
          )
        else if (_selectedPreset?.allowsCustomModel == true)
          GlassTextField(
            controller: _customModelController,
            hint: 'ناوی مۆدێل بنووسە...',
            onChanged: (value) {
              setState(() {
                _modelUserChosen = value.trim().isNotEmpty;
                _saveStatus = null;
              });
            },
          )
        else
          GlassTextField(
            controller: _customModelController,
            hint: _selectedModel,
            onChanged: (value) {
              _selectedModel = value.trim();
              _saveStatus = null;
            },
          ),

        const SizedBox(height: 16),

        // ── Action Buttons ──
        Row(
          children: [
            Expanded(
              child: GlassButton(
                label: _isSaving
                    ? 'پاشەکەوتکردن...'
                    : 'پاشەکەوتکردن',
                variant: GlassButtonVariant.filled,
                icon: Icons.save_outlined,
                onPressed: _isSaving ? null : _saveConfig,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GlassButton(
                label: _isTesting
                    ? 'تاقیکردنەوە...'
                    : 'تاقیکردنەوە',
                variant: GlassButtonVariant.outlined,
                icon: Icons.wifi_tethering_rounded,
                onPressed: _isTesting ? null : _testConnection,
              ),
            ),
          ],
        ),

        // ── Status Messages ──
        if (_saveStatus != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _saveStatus!,
              style: TextStyle(
                fontSize: 12,
                color: _saveStatus!.contains('✓')
                    ? Colors.greenAccent
                    : Colors.redAccent,
              ),
            ),
          ),

        if (_testResult != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _testResult!,
              style: TextStyle(
                fontSize: 12,
                color: _testSucceeded
                    ? Colors.greenAccent
                    : Colors.redAccent,
              ),
            ),
          ),

        const SizedBox(height: 8),
      ],
    );
  }

  void _clearSaveStatus() {
    if (_saveStatus != null) {
      setState(() => _saveStatus = null);
    }
  }
}

/// Small violet-light label for form fields.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.violetLight,
      ),
    );
  }
}
