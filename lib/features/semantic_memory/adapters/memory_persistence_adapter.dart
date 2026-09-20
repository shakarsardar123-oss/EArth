/// Stub — MemoryPersistenceAdapter
/// Generated during static repair. Class was referenced by tests but absent from lib/.
/// TODO: Restore from Step 17 source if available.
abstract class MemoryPersistenceAdapter {
  Future<void> persist(dynamic entry);
  Future<void> delete(dynamic query);
}

class DefaultMemoryPersistenceAdapter implements MemoryPersistenceAdapter {
  @override
  Future<void> persist(dynamic entry) async {}
  @override
  Future<void> delete(dynamic query) async {}
}

class Step17MemoryPersistenceAdapter implements MemoryPersistenceAdapter {
  @override
  Future<void> persist(dynamic entry) async {}
  @override
  Future<void> delete(dynamic query) async {}
}
