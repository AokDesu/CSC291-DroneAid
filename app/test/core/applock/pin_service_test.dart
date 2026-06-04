// PinService: hash/verify, wrong-PIN rejection, lockout + persistence, salt
// uniqueness, iteration round-trip. Pure logic over an in-memory store — fast
// (iterations: 1000) and no platform channel.

import 'dart:math';

import 'package:droneaid/core/applock/app_lock_store.dart';
import 'package:droneaid/core/applock/pin_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'in_memory_app_lock_store.dart';

void main() {
  group('PinService', () {
    late InMemoryAppLockStore store;
    late PinService svc;

    setUp(() {
      store = InMemoryAppLockStore();
      svc = PinService(store, iterations: 1000, random: Random(1));
    });

    test('set then verify with the same PIN succeeds', () async {
      await svc.setPin('u1', '123456');
      final r = await svc.verifyPin('u1', '123456');
      expect(r.ok, isTrue);
      expect(await svc.hasPin('u1'), isTrue);
    });

    test('wrong PIN is rejected and decrements remaining attempts', () async {
      await svc.setPin('u1', '123456');
      final r = await svc.verifyPin('u1', '000000');
      expect(r.ok, isFalse);
      expect(r.lockedOut, isFalse);
      expect(r.remainingAttempts, 4);
    });

    test('locks out after 5 wrong attempts; correct PIN inside window still blocked', () async {
      await svc.setPin('u1', '123456');
      late PinVerifyResult last;
      for (var i = 0; i < 5; i++) {
        last = await svc.verifyPin('u1', '000000');
      }
      expect(last.lockedOut, isTrue);
      expect(last.retryAfter, isNotNull);
      // Even the right PIN is refused while the cooldown is active.
      final blocked = await svc.verifyPin('u1', '123456');
      expect(blocked.ok, isFalse);
      expect(blocked.lockedOut, isTrue);
    });

    test('cooldown expires after the window, then the correct PIN works', () async {
      var clock = DateTime(2026, 1, 1, 12, 0, 0);
      final s = PinService(store, iterations: 1000, random: Random(2), clock: () => clock);
      await s.setPin('u1', '123456');
      for (var i = 0; i < 5; i++) {
        await s.verifyPin('u1', '000000');
      }
      clock = clock.add(const Duration(seconds: 31));
      final r = await s.verifyPin('u1', '123456');
      expect(r.ok, isTrue);
    });

    test('lockout survives a "restart" (fresh service over the same store)', () async {
      await svc.setPin('u1', '123456');
      for (var i = 0; i < 5; i++) {
        await svc.verifyPin('u1', '000000');
      }
      // New PinService instance, same persisted map → still locked out.
      final restarted = PinService(store, iterations: 1000, random: Random(9));
      final r = await restarted.verifyPin('u1', '123456');
      expect(r.lockedOut, isTrue);
    });

    test('a correct PIN before lockout resets the failed-attempt counter', () async {
      await svc.setPin('u1', '123456');
      await svc.verifyPin('u1', '000000'); // 1 fail
      await svc.verifyPin('u1', '000000'); // 2 fails
      await svc.verifyPin('u1', '123456'); // success → reset
      final r = await svc.verifyPin('u1', '000000');
      expect(r.remainingAttempts, 4); // counter restarted, not at 2
    });

    test('salts (and hashes) are unique across two setPin calls', () async {
      await svc.setPin('u1', '123456');
      final salt1 = store.map['u1/${AppLockKeys.pinSalt}'];
      final hash1 = store.map['u1/${AppLockKeys.pinHash}'];
      await svc.setPin('u1', '123456');
      final salt2 = store.map['u1/${AppLockKeys.pinSalt}'];
      final hash2 = store.map['u1/${AppLockKeys.pinHash}'];
      expect(salt1, isNotNull);
      expect(salt1, isNot(salt2));
      expect(hash1, isNot(hash2));
    });

    test('clearPin wipes the secret and counters', () async {
      await svc.setPin('u1', '123456');
      await svc.clearPin('u1');
      expect(await svc.hasPin('u1'), isFalse);
      expect(store.map.keys.where((k) => k.startsWith('u1/')), isEmpty);
    });

    test('verify reproduces with the STORED iteration count, not the default', () async {
      await svc.setPin('u1', '123456'); // stored with iterations: 1000
      final other = PinService(store, iterations: 5000, random: Random(3));
      final r = await other.verifyPin('u1', '123456');
      expect(r.ok, isTrue);
    });

    test('per-uid isolation: user B is not gated by user A PIN', () async {
      await svc.setPin('a', '123456');
      expect(await svc.hasPin('b'), isFalse);
      final r = await svc.verifyPin('b', '123456');
      expect(r.ok, isFalse);
    });

    test('biometric flag round-trips per uid', () async {
      expect(await svc.isBiometricEnabled('u1'), isFalse);
      await svc.setBiometricEnabled('u1', true);
      expect(await svc.isBiometricEnabled('u1'), isTrue);
    });
  });
}
