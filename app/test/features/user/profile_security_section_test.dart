// Profile → Security section: renders, gates the fingerprint toggle, routes to
// the set-PIN flow, and turning the lock off clears the stored PIN. Also guards
// the Firestore-exclusion constraint: buildProfilePatch never carries a PIN.

import 'dart:math';

import 'package:droneaid/core/applock/app_lock_providers.dart';
import 'package:droneaid/core/applock/app_lock_store.dart';
import 'package:droneaid/core/applock/pin_service.dart';
import 'package:droneaid/core/auth/auth_providers.dart';
import 'package:droneaid/core/auth/user_profile.dart';
import 'package:droneaid/features/user/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/applock/fake_biometric_service.dart';
import '../../core/applock/in_memory_app_lock_store.dart';

UserProfile _user() => const UserProfile(
      uid: 'u1',
      nationalId: '1100000000105',
      name: 'Mali',
      phone: '0812345678',
      role: 'user',
      locked: false,
    );

Future<({AppLockController controller, InMemoryAppLockStore store})> _controller({
  bool withPin = false,
  bool bioAvailable = false,
}) async {
  final store = InMemoryAppLockStore();
  final pin = PinService(store, iterations: 1000, random: Random(1));
  final bio = FakeBiometricService(available: bioAvailable);
  if (withPin) await pin.setPin('u1', '123456');
  final c = AppLockController(pinService: pin, biometric: bio, bindLifecycle: false);
  await c.onUserChanged('u1');
  return (controller: c, store: store);
}

Widget _wrap(AppLockController c) {
  return ProviderScope(
    overrides: [
      appLockControllerProvider.overrideWith((ref) => c),
      userProfileProvider.overrideWith((ref) async => _user()),
    ],
    child: const MaterialApp(home: ProfilePage()),
  );
}

// Tall surface so the whole (lazy) ListView builds — the Security card sits
// near the bottom and otherwise wouldn't be instantiated in the viewport.
// Must run inside the test body (setSurfaceSize asserts inTest).
Future<void> _tallSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('Profile Security section', () {
    testWidgets('renders with lock off and fingerprint toggle disabled', (tester) async {
      final h = await _controller();
      await _tallSurface(tester);
      await tester.pumpWidget(_wrap(h.controller));
      await tester.pumpAndSettle();

      expect(find.text('Security'), findsOneWidget);
      final lockSwitch = tester.widget<SwitchListTile>(find.byKey(const Key('applock-switch')));
      expect(lockSwitch.value, isFalse);

      expect(find.text('Set a PIN first'), findsOneWidget);
      final bioSwitch = tester.widget<SwitchListTile>(find.byKey(const Key('biometric-switch')));
      expect(bioSwitch.onChanged, isNull); // disabled until a PIN exists
    });

    testWidgets('turning the lock on routes to the set-PIN flow', (tester) async {
      final h = await _controller();
      await _tallSurface(tester);
      await tester.pumpWidget(_wrap(h.controller));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('applock-switch')));
      await tester.pumpAndSettle();
      expect(find.text('Choose a 6-digit PIN'), findsOneWidget);
    });

    testWidgets('turning the lock off clears the stored PIN', (tester) async {
      final h = await _controller(withPin: true);
      await _tallSurface(tester);
      await tester.pumpWidget(_wrap(h.controller));
      await tester.pumpAndSettle();

      final lockSwitch = tester.widget<SwitchListTile>(find.byKey(const Key('applock-switch')));
      expect(lockSwitch.value, isTrue);

      await tester.tap(find.byKey(const Key('applock-switch')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Turn off'));
      await tester.pumpAndSettle();

      expect(h.store.map.containsKey('u1/${AppLockKeys.pinHash}'), isFalse);
      expect(h.controller.state.hasPin, isFalse);
    });
  });

  group('buildProfilePatch (Firestore-exclusion guard)', () {
    test('never emits a PIN or biometric key', () {
      final patch = buildProfilePatch(
        initial: _user(),
        name: 'Mali R.',
        phone: '0900000000',
        lat: 13.7,
        lng: 100.5,
        label: 'Home',
        theme: 'dark',
        notificationsEnabled: false,
      );
      expect(
        patch.keys.any((k) => k.toLowerCase().contains('pin') || k.toLowerCase().contains('biometric')),
        isFalse,
      );
    });
  });
}
