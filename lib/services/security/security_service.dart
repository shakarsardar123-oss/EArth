/// Abstraction for app-level security features.
///
/// Phase 2+ will implement biometric auth, encryption, etc.
/// Phase 1 provides the contract only.
abstract class SecurityService {
  /// Whether the device supports biometric authentication.
  Future<bool> isBiometricAvailable();

  /// Authenticates the user via biometrics.
  ///
  /// Returns `true` on success, `false` on failure or cancellation.
  Future<bool> authenticateWithBiometrics({
    String reason = 'Please authenticate to continue',
  });

  /// Encrypts [data] using a device-specific key.
  Future<String> encrypt(String data);

  /// Decrypts [encryptedData] previously encrypted by [encrypt].
  Future<String> decrypt(String encryptedData);
}
