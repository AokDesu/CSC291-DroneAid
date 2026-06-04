// PIN cryptography + brute-force lockout, over an [AppLockStore].
//
// HONEST THREAT MODEL: a 4–6 digit PIN has only 10^4–10^6 entropy. PBKDF2 does
// NOT make it offline-brute-force-proof. The real defences are (a) the
// Keystore-backed store protecting the hash at rest and (b) the lockout below
// throttling online guesses. PBKDF2 is defence-in-depth — it slows an attacker
// who has already extracted the hash. Do not describe this as "unbreakable".

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import 'app_lock_store.dart';

/// Outcome of a PIN check. Carries lockout info so the UI can show a countdown.
class PinVerifyResult {
  const PinVerifyResult._({
    required this.ok,
    required this.lockedOut,
    this.retryAfter,
    this.remainingAttempts = 0,
  });

  const PinVerifyResult.success() : this._(ok: true, lockedOut: false);
  const PinVerifyResult.wrong(int remaining)
      : this._(ok: false, lockedOut: false, remainingAttempts: remaining);
  const PinVerifyResult.lockedOut(Duration retryAfter)
      : this._(ok: false, lockedOut: true, retryAfter: retryAfter);

  /// True only when the PIN matched.
  final bool ok;

  /// True when the attempt was rejected because we are inside the cooldown
  /// window (the PIN was not even hashed).
  final bool lockedOut;

  /// How long until the next attempt is allowed (only set when [lockedOut]).
  final Duration? retryAfter;

  /// Attempts left before lockout (only meaningful when [ok] is false and not
  /// [lockedOut]).
  final int remainingAttempts;
}

class PinService {
  PinService(
    this._store, {
    int iterations = 100000,
    Random? random,
    DateTime Function()? clock,
    int maxAttempts = 5,
  })  : _iterations = iterations,
        _random = random ?? Random.secure(),
        _now = clock ?? DateTime.now,
        _maxAttempts = maxAttempts;

  final AppLockStore _store;
  final int _iterations;
  final Random _random;
  final DateTime Function() _now;
  final int _maxAttempts;

  static const _algoVersion = 1;
  static const _saltBytes = 16;
  static const _keyBytes = 32;

  String _k(String uid, String suffix) => '$uid/$suffix';

  // ---- enrolment -----------------------------------------------------------

  Future<bool> hasPin(String uid) async =>
      (await _store.read(_k(uid, AppLockKeys.pinHash))) != null;

  /// (Re)sets the PIN for [uid]: fresh salt, PBKDF2 hash, counters cleared.
  Future<void> setPin(String uid, String pin) async {
    final salt = _genSalt();
    final hash = _pbkdf2(pin, salt, _iterations);
    await _store.write(_k(uid, AppLockKeys.pinSalt), base64Encode(salt));
    await _store.write(_k(uid, AppLockKeys.pinHash), base64Encode(hash));
    await _store.write(_k(uid, AppLockKeys.pinIterations), '$_iterations');
    await _store.write(_k(uid, AppLockKeys.pinAlgoVersion), '$_algoVersion');
    await _resetAttempts(uid);
  }

  /// Wipes the PIN + biometric flag + lockout counters for [uid].
  Future<void> clearPin(String uid) async {
    await _store.delete(_k(uid, AppLockKeys.pinSalt));
    await _store.delete(_k(uid, AppLockKeys.pinHash));
    await _store.delete(_k(uid, AppLockKeys.pinIterations));
    await _store.delete(_k(uid, AppLockKeys.pinAlgoVersion));
    await _store.delete(_k(uid, AppLockKeys.biometricEnabled));
    await _store.delete(_k(uid, AppLockKeys.failedAttempts));
    await _store.delete(_k(uid, AppLockKeys.lockoutUntil));
  }

  // ---- verification --------------------------------------------------------

  Future<PinVerifyResult> verifyPin(String uid, String pin) async {
    // 1. Inside the cooldown window? Reject without hashing.
    final lockedFor = await _remainingLockout(uid);
    if (lockedFor != null) return PinVerifyResult.lockedOut(lockedFor);

    final saltB64 = await _store.read(_k(uid, AppLockKeys.pinSalt));
    final hashB64 = await _store.read(_k(uid, AppLockKeys.pinHash));
    if (saltB64 == null || hashB64 == null) {
      return PinVerifyResult.wrong(_maxAttempts);
    }
    final iterations =
        int.tryParse(await _store.read(_k(uid, AppLockKeys.pinIterations)) ?? '') ??
            _iterations;

    final candidate = _pbkdf2(pin, base64Decode(saltB64), iterations);
    if (_constantTimeEquals(candidate, base64Decode(hashB64))) {
      await _resetAttempts(uid);
      return const PinVerifyResult.success();
    }

    // 2. Wrong PIN — bump the counter (persisted, so a force-kill can't reset).
    final attempts =
        (int.tryParse(await _store.read(_k(uid, AppLockKeys.failedAttempts)) ?? '') ?? 0) + 1;
    await _store.write(_k(uid, AppLockKeys.failedAttempts), '$attempts');
    if (attempts >= _maxAttempts) {
      final cooldown = _cooldownFor(attempts);
      final until = _now().add(cooldown).millisecondsSinceEpoch;
      await _store.write(_k(uid, AppLockKeys.lockoutUntil), '$until');
      return PinVerifyResult.lockedOut(cooldown);
    }
    return PinVerifyResult.wrong(_maxAttempts - attempts);
  }

  // ---- biometric opt-in flag (per uid) -------------------------------------

  Future<bool> isBiometricEnabled(String uid) async =>
      (await _store.read(_k(uid, AppLockKeys.biometricEnabled))) == 'true';

  Future<void> setBiometricEnabled(String uid, bool enabled) =>
      _store.write(_k(uid, AppLockKeys.biometricEnabled), '$enabled');

  // ---- internals -----------------------------------------------------------

  Future<void> _resetAttempts(String uid) async {
    await _store.write(_k(uid, AppLockKeys.failedAttempts), '0');
    await _store.delete(_k(uid, AppLockKeys.lockoutUntil));
  }

  /// Returns the remaining cooldown, or null if not locked out.
  Future<Duration?> _remainingLockout(String uid) async {
    final raw = await _store.read(_k(uid, AppLockKeys.lockoutUntil));
    if (raw == null) return null;
    final untilMs = int.tryParse(raw);
    if (untilMs == null) return null;
    final remaining = untilMs - _now().millisecondsSinceEpoch;
    return remaining > 0 ? Duration(milliseconds: remaining) : null;
  }

  /// 5 wrong → 30s, then doubling, capped at 5 min.
  Duration _cooldownFor(int attempts) {
    final over = attempts - _maxAttempts; // 0,1,2,...
    final seconds = min(30 * (1 << over), 300);
    return Duration(seconds: seconds);
  }

  Uint8List _genSalt() {
    final bytes = Uint8List(_saltBytes);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes;
  }

  Uint8List _pbkdf2(String pin, Uint8List salt, int iterations) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, iterations, _keyBytes));
    return derivator.process(Uint8List.fromList(utf8.encode(pin)));
  }

  /// Length-independent-branch compare to avoid leaking match position.
  bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
