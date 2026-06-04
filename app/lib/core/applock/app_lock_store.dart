// Key/value persistence for the device-local app-lock secret.
//
// `applock` namespace is deliberate: it must NOT collide with the unrelated map
// delivery-`pin_picker` / `DeliveryPin` (features/user/request) nor with the
// server-side `UserProfile.locked` admin flag. Nothing here ever touches
// Firestore — the PIN hash + lockout counters are device-local only.
//
// Keys are namespaced per Firebase uid (`<uid>/<key>`) so that signing out and
// a different user signing in on the same device is evaluated against that
// user's own keys — user B is never gated by user A's PIN.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Storage key suffixes (the stored key is `<uid>/<suffix>`).
class AppLockKeys {
  AppLockKeys._();
  static const pinSalt = 'pin_salt';
  static const pinHash = 'pin_hash';
  static const pinIterations = 'pin_iterations';
  static const pinAlgoVersion = 'pin_algo_version';
  static const biometricEnabled = 'biometric_enabled';
  static const failedAttempts = 'failed_attempts';
  static const lockoutUntil = 'lockout_until';
}

/// Thin async key/value seam. The production impl is Keystore-backed; tests
/// inject an in-memory map so the suite needs no platform channel.
abstract class AppLockStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Production [AppLockStore] over `flutter_secure_storage` (9.x).
///
/// `encryptedSharedPreferences: true` backs storage with AES-256 keys held in
/// the Android Keystore (not extractable, survives `adb` backup) — the reason
/// the PIN hash lives here and not in the plaintext SharedPreferences used by
/// `theme_mode_provider.dart`.
class SecureAppLockStore implements AppLockStore {
  SecureAppLockStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
