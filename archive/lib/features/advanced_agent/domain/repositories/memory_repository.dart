/// memory_repository.dart
/// AURA Assistant – Step 25: Adapter target for Step 17 MemoryRepository
///
/// Exact signature match from Step 23.
/// This interface MUST be implemented by Step17MemoryAdapter.
library;

/// Abstract repository matching Step 23's MemoryRepository.
/// lookup(userRequest, locale) → String?
/// isAvailable() → bool
abstract class MemoryRepository {
  Future<String?> lookup(String userRequest, String locale);
  bool isAvailable();
}
