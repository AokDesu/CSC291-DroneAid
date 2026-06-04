// AppLockController grace-window math via an injected clock. The lifecycle
// callbacks (handlePaused/handleResumed) are driven directly — bindLifecycle is
// false so no WidgetsBinding is needed and this stays a pure `test()`.

import 'dart:math';

import 'package:droneaid/core/applock/app_lock_providers.dart';
import 'package:droneaid/core/applock/pin_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_biometric_service.dart';
import 'in_memory_app_lock_store.dart';

void main() {
  group('AppLockController', () {
    late InMemoryAppLockStore store;
    late PinService pin;
    late FakeBiometricService bio;
    DateTime clock = DateTime(2026, 1, 1, 12, 0, 0);

    AppLockController build() => AppLockController(
          pinService: pin,
          biometric: bio,
          graceWindow: const Duration(seconds: 30),
          clock: () => clock,
          bindLifecycle: false,
        );

    setUp(() {
      store = InMemoryAppLockStore();
      pin = PinService(store, iterations: 1000, random: Random(1), clock: () => clock);
      bio = FakeBiometricService();
      clock = DateTime(2026, 1, 1, 12, 0, 0);
    });

    test('no PIN set → disabled, never locks', () async {
      final c = build();
      await c.onUserChanged('u1');
      expect(c.state.status, AppLockStatus.disabled);
    });

    test('cold start with a PIN set → locked', () async {
      await pin.setPin('u1', '123456');
      final c = build();
      await c.onUserChanged('u1');
      expect(c.state.status, AppLockStatus.locked);
    });

    test('loading auth never collapses to disabled (no content flash for PIN users)', () async {
      await pin.setPin('u1', '123456');
      final c = build();
      expect(c.state.status, AppLockStatus.unknown);
      // Auth still loading (fireImmediately fires with uid == null): must NOT
      // become disabled, or the gate would paint content during hydrate.
      await c.onAuthState(isLoading: true, uid: null);
      expect(c.state.status, AppLockStatus.unknown);
      // Auth resolves to the signed-in user → straight to locked.
      await c.onAuthState(isLoading: false, uid: 'u1');
      expect(c.state.status, AppLockStatus.locked);
    });

    test('resume within the grace window stays unlocked', () async {
      await pin.setPin('u1', '123456');
      final c = build();
      await c.onUserChanged('u1');
      await c.verifyPin('123456');
      expect(c.state.status, AppLockStatus.unlocked);

      c.handlePaused();
      clock = clock.add(const Duration(seconds: 10));
      c.handleResumed();
      expect(c.state.status, AppLockStatus.unlocked);
    });

    test('resume past the grace window re-locks', () async {
      await pin.setPin('u1', '123456');
      final c = build();
      await c.onUserChanged('u1');
      await c.verifyPin('123456');

      c.handlePaused();
      clock = clock.add(const Duration(seconds: 31));
      c.handleResumed();
      expect(c.state.status, AppLockStatus.locked);
    });

    test('resume with no recorded background timestamp locks defensively', () async {
      await pin.setPin('u1', '123456');
      final c = build();
      await c.onUserChanged('u1');
      await c.verifyPin('123456');

      c.handleResumed(); // no handlePaused() first
      expect(c.state.status, AppLockStatus.locked);
    });

    test('sign-out disables without wiping the stored PIN', () async {
      await pin.setPin('u1', '123456');
      final c = build();
      await c.onUserChanged('u1');
      await c.onUserChanged(null);
      expect(c.state.status, AppLockStatus.disabled);
      // Same user signing back in is still gated.
      await c.onUserChanged('u1');
      expect(c.state.status, AppLockStatus.locked);
    });

    test('lockNow re-locks an unlocked session', () async {
      await pin.setPin('u1', '123456');
      final c = build();
      await c.onUserChanged('u1');
      await c.verifyPin('123456');
      c.lockNow();
      expect(c.state.status, AppLockStatus.locked);
    });

    test('biometric availability reflected in state', () async {
      bio.available = true;
      await pin.setPin('u1', '123456');
      await pin.setBiometricEnabled('u1', true);
      final c = build();
      await c.onUserChanged('u1');
      expect(c.state.canUseBiometric, isTrue);
    });
  });
}
