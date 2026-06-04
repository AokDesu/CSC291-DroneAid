// Fingerprint/biometric gate, wrapping `local_auth`.
//
// `biometricOnly: true` is deliberate: with it false, Android would offer the
// DEVICE credential (the phone's own lock PIN/pattern) as a fallback, which
// would bypass our app-specific PIN and its lockout counter entirely. We want
// biometric-or-our-PIN, so biometric failure/cancel falls back to our keypad —
// not to the OS credential.

import 'package:local_auth/local_auth.dart';

/// Testable seam over `local_auth`. Tests inject a fake; the real plugin has no
/// behaviour under `flutter test` (the method channel is absent).
abstract class BiometricService {
  /// Device has biometric hardware AND at least one enrolled credential.
  Future<bool> isAvailable();

  /// Prompts the OS biometric sheet. Returns true on a successful scan.
  Future<bool> authenticate(String reason);
}

class LocalAuthBiometricService implements BiometricService {
  LocalAuthBiometricService([LocalAuthentication? auth])
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> isAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;
      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) return false;
      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      // PlatformException (no hardware / cancelled / too many attempts) → fall
      // back to PIN rather than crashing the lock screen.
      return false;
    }
  }
}
