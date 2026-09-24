/// tool_memory_adapter.dart
/// AURA Assistant – Step 20: Tool Registry & Memory
library;

import 'package:aura_assistant/features/tool_registry/application/contracts/tool_memory_adapter.dart';

export 'package:aura_assistant/features/tool_registry/application/contracts/tool_memory_adapter.dart';

import 'package:aura_assistant/features/tool_registry/domain/models/models.dart';

class DefaultToolMemoryAdapter implements ToolMemoryAdapter {
  bool _isAvailable = true;
  final Map<String, String> _store = {};
  final Map<String, List<String>> _tagIndex = {};

  DefaultToolMemoryAdapter({bool isAvailable = true})
      : _isAvailable = isAvailable;

  @override
  Future<ToolMemoryResult> store({
    required String key,
    required String value,
    List<String>? tags,
  }) async {
    if (!_isAvailable) {
      return ToolMemoryResult.failed(error: 'Memory adapter unavailable');
    }

    _store[key] = value;
    if (tags != null) {
      for (final tag in tags) {
        _tagIndex.putIfAbsent(tag, () => []).add(key);
      }
    }

    return ToolMemoryResult.ok();
  }

  @override
  Future<ToolMemoryResult> recall({required String key}) async {
    if (!_isAvailable) {
      return ToolMemoryResult.failed(error: 'Memory adapter unavailable');
    }

    final value = _store[key];
    if (value == null) {
      return ToolMemoryResult.failed(error: 'Key not found: $key');
    }

    return ToolMemoryResult.ok(data: value);
  }

  @override
  Future<ToolMemoryResult> search({
    required String query,
    List<String>? tags,
  }) async {
    if (!_isAvailable) {
      return ToolMemoryResult.failed(error: 'Memory adapter unavailable');
    }

    final results = <Map<String, String>>[];

    // Search by tags first.
    if (tags != null) {
      for (final tag in tags) {
        final keys = _tagIndex[tag] ?? const [];
        for (final k in keys) {
          if (_store.containsKey(k) &&
              !results.any((r) => r['key'] == k)) {
            results.add({'key': k, 'value': _store[k]!});
          }
        }
      }
    }

    // Also search by key substring.
    for (final entry in _store.entries) {
      if (entry.key.toLowerCase().contains(query.toLowerCase()) &&
          !results.any((r) => r['key'] == entry.key)) {
        results.add({'key': entry.key, 'value': entry.value});
      }
    }

    if (results.isEmpty) {
      return ToolMemoryResult.ok(data: null);
    }

    // Format as JSON array.
    final jsonEntries = results
        .map((r) => '{"key":"${r['key']}","value":"${r['value']}"}')
        .join(',');
    return ToolMemoryResult.ok(data: '[$jsonEntries]');
  }

  @override
  Future<ToolMemoryResult> forget({required String key}) async {
    if (!_isAvailable) {
      return ToolMemoryResult.failed(error: 'Memory adapter unavailable');
    }

    if (!_store.containsKey(key)) {
      return ToolMemoryResult.failed(error: 'Key not found: $key');
    }

    _store.remove(key);
    // Remove from tag index.
    for (final tagKeys in _tagIndex.values) {
      tagKeys.remove(key);
    }

    return ToolMemoryResult.ok();
  }

  @override
  bool get isAvailable => _isAvailable;

  /// Configure availability.
  void setAvailable(bool available) => _isAvailable = available;

  /// Clear all stored data (useful for testing).
  void clear() {
    _store.clear();
    _tagIndex.clear();
  }
}

/// Production adapter that bridges Step 17's MemoryManager.
///
/// Uses Step 17's remember/recall/search/forget API for
/// persistent tool memory.
class Step17MemoryAdapter implements ToolMemoryAdapter {
  /// The Step 17 MemoryManager instance.
  ///
  /// Type is dynamic to avoid direct import. Expected to implement:
  ///   remember(key, value, tags?) -> MemoryResult
  ///   recall(key) -> MemoryResult<T>
  ///   search(query, tags?) -> MemoryResult<List<MemoryEntry>>
  ///   forget(key) -> MemoryResult
  final dynamic _memoryManager;

  bool _isAvailable;

  /// Prefix for all tool-related memory keys.
  static const String _keyPrefix = 'tool_registry:';

  Step17MemoryAdapter({
    required dynamic memoryManager,
    bool isAvailable = true,
  })  : _memoryManager = memoryManager,
        _isAvailable = isAvailable;

  @override
  Future<ToolMemoryResult> store({
    required String key,
    required String value,
    List<String>? tags,
  }) async {
    if (!_isAvailable || _memoryManager == null) {
      return ToolMemoryResult.failed(error: 'Step 17 memory unavailable');
    }

    try {
      final fullKey = '$_keyPrefix$key';
      final allTags = ['tool_registry', ...?tags];

      final result = await _memoryManager.remember(
        fullKey,
        value,
        tags: allTags,
      );

      final successStr = result.toString().toLowerCase();
      if (successStr.contains('success')) {
        return ToolMemoryResult.ok();
      } else {
        return ToolMemoryResult.failed(error: 'Step 17 store failed: $result');
      }
    } catch (e) {
      return ToolMemoryResult.failed(error: 'Step 17 store threw: $e');
    }
  }

  @override
  Future<ToolMemoryResult> recall({required String key}) async {
    if (!_isAvailable || _memoryManager == null) {
      return ToolMemoryResult.failed(error: 'Step 17 memory unavailable');
    }

    try {
      final fullKey = '$_keyPrefix$key';
      final result = await _memoryManager.recall(fullKey);

      // Extract the value from the result.
      final resultStr = result.toString();
      if (resultStr.toLowerCase().contains('success') ||
          resultStr.toLowerCase().contains('found')) {
        // Try to get .data from the result.
        try {
          final data = result.data;
          return ToolMemoryResult.ok(data: data?.toString());
        } catch (_) {
          return ToolMemoryResult.ok(data: resultStr);
        }
      }

      return ToolMemoryResult.failed(error: 'Key not found: $key');
    } catch (e) {
      return ToolMemoryResult.failed(error: 'Step 17 recall threw: $e');
    }
  }

  @override
  Future<ToolMemoryResult> search({
    required String query,
    List<String>? tags,
  }) async {
    if (!_isAvailable || _memoryManager == null) {
      return ToolMemoryResult.failed(error: 'Step 17 memory unavailable');
    }

    try {
      final allTags = ['tool_registry', ...?tags];
      final result = await _memoryManager.search(
        query,
        tags: allTags,
      );

      return ToolMemoryResult.ok(data: result.toString());
    } catch (e) {
      return ToolMemoryResult.failed(error: 'Step 17 search threw: $e');
    }
  }

  @override
  Future<ToolMemoryResult> forget({required String key}) async {
    if (!_isAvailable || _memoryManager == null) {
      return ToolMemoryResult.failed(error: 'Step 17 memory unavailable');
    }

    try {
      final fullKey = '$_keyPrefix$key';
      await _memoryManager.forget(fullKey);
      return ToolMemoryResult.ok();
    } catch (e) {
      return ToolMemoryResult.failed(error: 'Step 17 forget threw: $e');
    }
  }

  @override
  bool get isAvailable => _isAvailable;

  /// Update availability.
  void setAvailable(bool available) => _isAvailable = available;
}
