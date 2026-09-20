/// Step 23 — Memory Repository Interface
///
/// Contract for the Step 17 Semantic Memory adapter.
/// FAIL-CLOSED: any memory failure returns null (safe degradation).
/// Null context does NOT block orchestration — it degrades safely.

abstract class MemoryRepository {
  /// Retrieve memory context relevant to the user request.
  /// Returns null if memory is unavailable or lookup fails.
  ///
  /// memoryContext is String? (per Step 17 contract).
  Future<String?> lookup(String userRequest, String locale);

  /// Check if memory is currently available (offline-safe check).
  Future<bool> isAvailable();
}
