/// connectivity_repository.dart
/// AURA Assistant – Step 25: Adapter target for Step 23 ConnectivityRepository
///
/// Exact signature match from Step 23.
library;

/// Abstract repository matching Step 23's ConnectivityRepository.
/// isOnline() → bool
/// onConnectivityChanged → Stream<bool>
abstract class ConnectivityRepository {
  bool isOnline();
  Stream<bool> get onConnectivityChanged;
}
