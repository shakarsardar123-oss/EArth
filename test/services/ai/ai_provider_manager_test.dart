import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/services/ai/ai_provider_manager.dart';
import 'package:aura_assistant/services/ai/ai_provider.dart';
import 'package:aura_assistant/domain/services/ai_service.dart';
import 'package:aura_assistant/core/errors/failures.dart';

void main() {
  group('AIProviderManager', () {
    late AIProviderManager manager;

    setUp(() {
      manager = AIProviderManager();
    });

    test('starts with empty providers list', () {
      expect(manager.providers, isEmpty);
    });

    test('registerProvider adds a provider', () {
      final provider = _FakeAIProvider(
        id: 'test-id',
        supportedModels: ['model-a'],
      );
      manager.registerProvider(provider);
      expect(manager.providers.length, 1);
      expect(manager.providers.first.id, 'test-id');
    });

    test('registerProvider adds multiple providers', () {
      manager.registerProvider(
        _FakeAIProvider(id: 'a', supportedModels: ['model-a']),
      );
      manager.registerProvider(
        _FakeAIProvider(id: 'b', supportedModels: ['model-b']),
      );
      expect(manager.providers.length, 2);
    });

    test('unregisterProvider removes the provider', () {
      final provider = _FakeAIProvider(
        id: 'remove-me',
        supportedModels: ['model-x'],
      );
      manager.registerProvider(provider);
      expect(manager.providers.length, 1);
      manager.unregisterProvider('remove-me');
      expect(manager.providers, isEmpty);
    });

    test('unregisterProvider does nothing if provider not found', () {
      manager.registerProvider(
        _FakeAIProvider(id: 'a', supportedModels: ['model-a']),
      );
      manager.unregisterProvider('non-existent');
      expect(manager.providers.length, 1);
    });

    test('resolveProvider returns Success when a provider supports the model', () {
      final provider = _FakeAIProvider(
        id: 'openai',
        supportedModels: ['gpt-4', 'gpt-3.5-turbo'],
      );
      manager.registerProvider(provider);
      final result = manager.resolveProvider('gpt-4');
      expect(result.isSuccess, isTrue);
      result.when(
        success: (p) => expect(p.id, 'openai'),
        failure: (_) => fail('Expected success'),
      );
    });

    test('resolveProvider returns FailureResult when no provider supports the model', () {
      final result = manager.resolveProvider('non-existent-model');
      expect(result.isFailure, isTrue);
      result.when(
        success: (_) => fail('Expected failure'),
        failure: (f) => expect(f, isA<UnexpectedFailure>()),
      );
    });

    test('resolveProvider returns correct provider among multiple', () {
      manager.registerProvider(
        _FakeAIProvider(id: 'openai', supportedModels: ['gpt-4']),
      );
      manager.registerProvider(
        _FakeAIProvider(id: 'anthropic', supportedModels: ['claude-3']),
      );
      final result = manager.resolveProvider('claude-3');
      expect(result.isSuccess, isTrue);
      result.when(
        success: (p) => expect(p.id, 'anthropic'),
        failure: (_) => fail('Expected success'),
      );
    });

    test('resolveProvider does not match by provider id, only by model', () {
      manager.registerProvider(
        _FakeAIProvider(id: 'openai', supportedModels: ['gpt-4']),
      );
      // Resolving by provider id (not model id) should fail
      final result = manager.resolveProvider('openai');
      expect(result.isFailure, isTrue);
    });
  });
}

class _FakeAIProvider implements AIProvider {
  
  final String id;

  
  String get displayName => 'Fake Provider';

  final List<String> _supportedModels;

  _FakeAIProvider({
    required this.id,
    required List<String> supportedModels,
  }) : _supportedModels = supportedModels;

  
  List<String> get supportedModels => _supportedModels;

  
  bool supportsModel(String modelId) => _supportedModels.contains(modelId);

  
  Future<AIResponse> complete(AIRequest request) {
    throw UnimplementedError();
  }

  
  Stream<AIResponse> streamComplete(AIRequest request) {
    throw UnimplementedError();
  }
}
