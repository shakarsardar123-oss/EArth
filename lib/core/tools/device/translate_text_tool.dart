/// Phase 6 — Translate Text Tool.
///
/// Translates text between languages using the AI service directly.
/// Reuses the same [AIProvider] already wired in app_providers.dart via
/// [selectedAIProviderProvider], so no new API keys or network code
/// are needed — it goes through the existing Gemini/OpenAI path.
///
/// **Honesty:** the tool returns whatever the AI model produces; it does
/// NOT fabricate translations on its own. A short system prompt is
/// injected to constrain the model to pure translation output.
library;

import '../tool.dart';
import '../tool_definition.dart';
import '../tool_permission.dart';
import '../tool_arguments.dart';
import '../tool_result.dart';
import '../../agent/agent_confirmation_manager.dart';
import '../../../domain/services/ai_service.dart';
import '../../../domain/entities/agent_config.dart';
import '../../../core/ai/ai_message.dart';
import '../../../services/ai/ai_provider.dart';
import '../../../core/errors/result.dart';

class TranslateTextTool extends Tool {
  final AIProvider _aiProvider;

  /// Default agent config shape used ONLY for the translation request.
  /// Temperature 0.3 for deterministic output; no API keys stored here.
  static const AgentConfig _translateConfig = AgentConfig(
    id: '_translate_tool',
    name: 'Translate',
    description: 'Translation request',
    systemPrompt:
        'You are a translation engine. Translate the given text to the '
        'target language. Output ONLY the translated text, nothing else. '
        'Do NOT add explanations, notes, or the original text.',
    modelId: 'gemini-1.5-flash',
    temperature: 0.3,
    maxTokens: 1024,
    isDefault: false,
    isActive: true,
  );

  TranslateTextTool(this._aiProvider);

  @override
  ToolDefinition get definition => const ToolDefinition(
        name: 'translate_text',
        description:
            'دەق وەرگێڕێتەوە بۆ زمانی مەبەست بە رێگەی AI. '
            '— '
            'Translate text to a target language using the AI model. '
            'The output is whatever the AI produces; no post-processing.',
        category: 'device',
        parameters: [
          ToolArgumentDef(
            name: 'text',
            type: 'string',
            description:
                'دەقەکەی ئەوی وەرگێڕدرێت. — The text to translate.',
            isRequired: true,
            example: 'Hello, how are you?',
            label: 'دەق',
            hintText: 'Hello, how are you?',
          ),
          ToolArgumentDef(
            name: 'target_language',
            type: 'string',
            description:
                'زمانی مەبەست (کوردی سۆرانی=ckb, ئینگلیزی=en, عەرەبی=ar, ...). '
                '— Target language code or name (ckb, en, ar, ...).',
            isRequired: true,
            example: 'ckb',
            label: 'زمانی مەبەست',
            hintText: 'ckb',
          ),
        ],
        permissionRequirements: [
          ToolPermissionRequirement(
            permission: ToolPermission.network,
            isRequired: true,
            rationale:
                'پێویستە هێڵی ئینتەرنێت بۆ وەرگێڕان. '
                '— '
                'Network access is required for AI-based translation.',
          ),
        ],
        isDangerous: false,
        requiresConfirmation: false,
        tags: ['device', 'translate', 'language', 'وەرگێڕان'],
        icon: 'translate',
        timeout: Duration(seconds: 30),
        riskLevel: ToolRiskLevel.low,
      );

  @override
  String? validateArguments(ToolArguments arguments) {
    final text = arguments.getString('text');
    final target = arguments.getString('target_language');
    if (text == null || text.trim().isEmpty) {
      return 'text is required and cannot be empty. — دەق پێویستە.';
    }
    if (target == null || target.trim().isEmpty) {
      return 'target_language is required. — زمانی مەبەست پێویستە.';
    }
    if (text.length > 5000) {
      return 'text is too long (max 5000 chars). '
          '— دەق زۆر درێژە (زۆرترین 5000 پیت).';
    }
    return null;
  }

  @override
  Future<ToolResult> execute(ToolArguments arguments) async {
    final validationError = validateArguments(arguments);
    if (validationError != null) {
      return ToolResult.failure(validationError, errorCode: 'invalidArguments');
    }

    final text = arguments.getString('text')!;
    final targetLang = arguments.getString('target_language')!;

    final prompt = 'Translate the following text to $targetLang:\n\n$text';

    try {
      final request = AIRequest(
        prompt: prompt,
        agentConfig: _translateConfig,
        messages: [
          AIMessage(
            role: AIMessageRole.system,
            content: _translateConfig.systemPrompt,
          ),
          AIMessage(role: AIMessageRole.user, content: prompt),
        ],
      );

      final response = await _aiProvider.complete(request);

      if (response.text.trim().isEmpty) {
        return const ToolResult.failure(
          'AI returned empty translation. '
          '— AI وەرگێڕانێکی بەتاڵی گەڕاند.',
          errorCode: 'emptyResponse',
        );
      }

      return ToolResult.success({
        'original_text': text,
        'target_language': targetLang,
        'translated_text': response.text.trim(),
        'model_id': response.modelId,
      });
    } catch (e) {
      return ToolResult.failure(
        'Translation error: $e',
        errorCode: 'internalError',
      );
    }
  }
}
