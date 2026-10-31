/// Stub — MemorySecurityAdapter
/// Generated during static repair. Class was referenced by tests but absent from lib/.
/// TODO: Restore from Step 17 source if available.
abstract class MemorySecurityAdapter {
  Future<bool> isAllowed(dynamic operation, dynamic data);
  Future<void> audit(dynamic operation, dynamic result);
}

class DefaultMemorySecurityAdapter implements MemorySecurityAdapter {
  @override
  Future<bool> isAllowed(dynamic operation, dynamic data) async => false;
  @override
  Future<void> audit(dynamic operation, dynamic result) async {}
}

class Step17MemorySecurityAdapter implements MemorySecurityAdapter {
  @override
  Future<bool> isAllowed(dynamic operation, dynamic data) async => false;
  @override
  Future<void> audit(dynamic operation, dynamic result) async {}
}
