/// stub_memory_embedding_service_test.dart
/// Structural tests for StubMemoryEmbeddingService.
library;

import 'package:test/test.dart';

// ─── Inline mirrors for structural testing ─────────────────────────

enum MemoryFailurePhase { storage, embedding, search, policy, unknown }

class MemoryFailure {
  final MemoryFailurePhase phase;
  final String message;
  MemoryFailure({required this.phase, required this.message});
}

class Result<S, F> {
  final S? _s; final F? _f; final bool _ok;
  Result._(this._s, this._f, this._ok);
  factory Result.success(S v) => Result._(v, null, true);
  factory Result.failure(F v) => Result._(null, v, false);
  bool get isSuccess => _ok; bool get isFailure => !_ok;
  S get value => _s as S; F get failure => _f as F;
}

typedef MemoryResult<T> = Result<T, MemoryFailure>;

/// Mirror of StubMemoryEmbeddingService.
class StubMemoryEmbeddingService {
  final int dimensions;
  bool _simulateFailure = false;

  StubMemoryEmbeddingService({this.dimensions = 64});

  void setSimulateFailure(bool simulate) => _simulateFailure = simulate;

  MemoryResult<List<double>> embed(String text) {
    if (_simulateFailure) return MemoryResult.failure(
      MemoryFailure(phase: MemoryFailurePhase.embedding, message: 'Embedding failed'),
    );
    if (text.isEmpty) return MemoryResult.failure(
      MemoryFailure(phase: MemoryFailurePhase.embedding, message: 'Cannot embed empty text'),
    );
    final bytes = text.codeUnits;
    final embedding = List.generate(dimensions, (i) {
      final byteVal = bytes[i % bytes.length];
      return (byteVal % 1000) / 1000.0;
    });
    return MemoryResult.success(embedding);
  }

  MemoryResult<List<List<double>>> embedBatch(List<String> texts) {
    if (_simulateFailure) return MemoryResult.failure(
      MemoryFailure(phase: MemoryFailurePhase.embedding, message: 'Batch embedding failed'),
    );
    final results = <List<double>>[];
    for (final text in texts) {
      final r = embed(text);
      if (r.isFailure) return MemoryResult.failure(r.failure);
      results.add(r.value);
    }
    return MemoryResult.success(results);
  }

  int get embeddingDimensions => dimensions;
}

void main() {
  group('StubMemoryEmbeddingService', () {
    late StubMemoryEmbeddingService service;

    setUp(() {
      service = StubMemoryEmbeddingService(dimensions: 32);
    });

    test('embed returns list of correct dimensions', () {
      final result = service.embed('hello world');
      expect(result.isSuccess, isTrue);
      expect(result.value, hasLength(32));
    });

    test('embed is deterministic — same input same output', () {
      final a = service.embed('test input');
      final b = service.embed('test input');
      expect(a.value, equals(b.value));
    });

    test('different inputs produce different embeddings', () {
      final a = service.embed('cat');
      final b = service.embed('dog');
      expect(a.value, isNot(equals(b.value)));
    });

    test('embed fails for empty text', () {
      final result = service.embed('');
      expect(result.isFailure, isTrue);
      expect(result.failure.phase, MemoryFailurePhase.embedding);
    });

    test('embedBatch returns embeddings for all texts', () {
      final result = service.embedBatch(['one', 'two', 'three']);
      expect(result.isSuccess, isTrue);
      expect(result.value, hasLength(3));
      for (final emb in result.value) {
        expect(emb, hasLength(32));
      }
    });

    test('embedBatch fails if any text is empty', () {
      final result = service.embedBatch(['ok', '', 'bad']);
      expect(result.isFailure, isTrue);
    });

    test('simulateFailure makes embed fail', () {
      service.setSimulateFailure(true);
      final result = service.embed('anything');
      expect(result.isFailure, isTrue);
      expect(result.failure.phase, MemoryFailurePhase.embedding);
    });

    test('simulateFailure makes embedBatch fail', () {
      service.setSimulateFailure(true);
      final result = service.embedBatch(['a', 'b']);
      expect(result.isFailure, isTrue);
    });

    test('embeddingDimensions returns configured value', () {
      expect(service.embeddingDimensions, 32);
      final big = StubMemoryEmbeddingService(dimensions: 128);
      expect(big.embeddingDimensions, 128);
    });

    test('default dimensions is 64', () {
      final defaultService = StubMemoryEmbeddingService();
      expect(defaultService.embeddingDimensions, 64);
      final result = defaultService.embed('test');
      expect(result.value, hasLength(64));
    });
  });
}
