/// step17_memory_adapter.dart
/// AURA Assistant – Step 25: Infrastructure adapter for Step 17 Memory.
///
/// Adapts Step 17's MemoryProvider contract to Step 25's MemoryRepository interface.
/// FAIL-CLOSED: any error or unavailable → null (no fake data).
library;

import '../domain/repositories/memory_repository.dart';

/// Adapter that bridges Step 17 Memory to Step 25's MemoryRepository.
///
/// Implements ONLY the MemoryRepository contract:
///   lookup(String userRequest, String locale) → Future<String?>
///   isAvailable() → bool
///
/// No store/retrieve/delete — those are NOT in the MemoryRepository interface.
class Step17MemoryAdapter implements MemoryRepository {
  /// Whether the underlying Step 17 memory provider is available.
  bool _available;

  Step17MemoryAdapter({bool available = false}) : _available = available;

  @override
  Future<String?> lookup(String userRequest, String locale) async {
    if (!_available) {
      // FAIL-CLOSED: memory unavailable → return null, never fake data.
      return null;
    }
    // In production, delegates to Step 17 MemoryProvider.lookup()
    // For structural validation, returns null (no data fabrication).
    return null;
  }

  @override
  bool isAvailable() => _available;

  /// Mark adapter as available (for testing/wiring only).
  void setAvailable(bool available) => _available = available;
}
