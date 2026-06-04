// Widget tests for the lock screen: PIN success/failure, lockout message,
// fingerprint visibility + success/fallback, and the Forgot-PIN escape.

import 'dart:math';

import 'package:droneaid/core/applock/app_lock_providers.dart';
import 'package:droneaid/core/applock/app_lock_store.dart';
import 'package:droneaid/core/applock/pin_service.dart';
import 'package:droneaid/core/auth/auth_providers.dart';
import 'package:droneaid/core/auth/auth_repository.dart';
import 'package:droneaid/features/applock/lock_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/applock/fake_biometric_service.dart';
import '../../core/applock/in_memory_app_lock_store.dart';

class _FakeAuthRepository implements AuthRepository {
  bool signedOut = false;

  @override
  Future<void> signOut() async => signedOut = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Harness {
  _Harness(this.controller, this.store, this.bio);
  final AppLockController controller;
  final InMemoryAppLockStore store;
  final FakeBiometricService bio;
}

Future<_Harness> _setup({
  bool withPin = true,
  bool bioAvailable = false,
  bool bioEnabled = false,
  bool authResult = false,
}) async {
  final store = InMemoryAppLockStore();
  final pin = PinService(store, iterations: 1000, random: Random(1));
  final bio = FakeBiometricService(available: bioAvailable, authResult: authResult);
  if (withPin) await pin.setPin('u1', '123456');
  if (bioEnabled) await pin.setBiometricEnabled('u1', true);
  final controller = AppLockController(pinService: pin, biometric: bio, bindLifecycle: false);
  await controller.onUserChanged('u1');
  return _Harness(controller, store, bio);
}

Widget _wrap(AppLockController c, {AuthRepository? auth}) {
  return ProviderScope(
    overrides: [
      appLockControllerProvider.overrideWith((ref) => c),
      if (auth != null) authRepositoryProvider.overrideWithValue(auth),
    ],
    child: const MaterialApp(home: LockScreen()),
  );
}

Future<void> _enter(WidgetTester tester, String pin) async {
  for (final d in pin.split('')) {
    await tester.tap(find.text(d));
    await tester.pump();
  }
}

// Tall surface so the (scrollable) lock screen fits fully on-screen and every
// keypad key is tappable. Must run inside the test body (setSurfaceSize asserts
// inTest), so it's a helper, not a setUp.
Future<void> _tallSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(420, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  group('LockScreen', () {
    testWidgets('correct PIN unlocks', (tester) async {
      final h = await _setup();
      await _tallSurface(tester);
      await tester.pumpWidget(_wrap(h.controller));
      await _enter(tester, '123456');
      await tester.pumpAndSettle();
      expect(h.controller.state.status, AppLockStatus.unlocked);
    });

    testWidgets('wrong PIN shows an error and stays locked', (tester) async {
      final h = await _setup();
      await _tallSurface(tester);
      await tester.pumpWidget(_wrap(h.controller));
      await _enter(tester, '000000');
      await tester.pumpAndSettle();
      expect(find.textContaining('Wrong PIN'), findsOneWidget);
      expect(h.controller.state.status, AppLockStatus.locked);
    });

    testWidgets('shows a cooldown message after 5 wrong attempts', (tester) async {
      final h = await _setup();
      await _tallSurface(tester);
      await tester.pumpWidget(_wrap(h.controller));
      for (var i = 0; i < 5; i++) {
        await _enter(tester, '000000');
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.textContaining('Too many tries'), findsOneWidget);
      expect(h.controller.state.status, AppLockStatus.locked);
      // Dispose the screen so its cooldown Timer.periodic is cancelled.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('no fingerprint button when biometric unavailable', (tester) async {
      final h = await _setup();
      await _tallSurface(tester);
      await tester.pumpWidget(_wrap(h.controller));
      await tester.pump();
      expect(find.byIcon(Icons.fingerprint), findsNothing);
    });

    testWidgets('biometric success auto-unlocks on mount', (tester) async {
      final h = await _setup(bioAvailable: true, bioEnabled: true, authResult: true);
      await _tallSurface(tester);
      await tester.pumpWidget(_wrap(h.controller));
      await tester.pumpAndSettle();
      expect(h.bio.authCalls, greaterThanOrEqualTo(1));
      expect(h.controller.state.status, AppLockStatus.unlocked);
    });

    testWidgets('biometric failure falls back to the keypad (stays locked)', (tester) async {
      final h = await _setup(bioAvailable: true, bioEnabled: true, authResult: false);
      await _tallSurface(tester);
      await tester.pumpWidget(_wrap(h.controller));
      await tester.pumpAndSettle();
      expect(h.controller.state.status, AppLockStatus.locked);
      expect(find.byIcon(Icons.fingerprint), findsOneWidget);
    });

    testWidgets('Forgot PIN signs out and clears the stored PIN', (tester) async {
      final h = await _setup();
      final auth = _FakeAuthRepository();
      await _tallSurface(tester);
      await tester.pumpWidget(_wrap(h.controller, auth: auth));
      await tester.tap(find.text('Forgot PIN? Sign out'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
      await tester.pumpAndSettle();
      expect(auth.signedOut, isTrue);
      expect(h.store.map.containsKey('u1/${AppLockKeys.pinHash}'), isFalse);
      expect(h.controller.state.status, AppLockStatus.disabled);
    });
  });
}
