import 'package:droneaid/core/auth/user_profile.dart';
import 'package:droneaid/features/user/profile_page.dart';
import 'package:flutter_test/flutter_test.dart';

UserProfile _initial({
  String? name = 'Mali',
  String? phone = '0812345678',
  Map<String, dynamic>? deliveryAddress,
  Map<String, dynamic>? prefs,
}) {
  return UserProfile(
    uid: 'u1',
    nationalId: '1100000000105',
    name: name,
    phone: phone,
    role: 'user',
    locked: false,
    deliveryAddress: deliveryAddress,
    prefs: prefs,
  );
}

void main() {
  group('buildProfilePatch', () {
    test('returns empty map when nothing changed', () {
      final p = buildProfilePatch(
        initial: _initial(),
        name: 'Mali',
        phone: '0812345678',
        lat: null,
        lng: null,
        label: '',
        theme: 'system',
        notificationsEnabled: true,
      );
      expect(p, isEmpty);
    });

    test('includes only the changed name', () {
      final p = buildProfilePatch(
        initial: _initial(),
        name: 'Mali R.',
        phone: '0812345678',
        lat: null,
        lng: null,
        label: '',
        theme: 'system',
        notificationsEnabled: true,
      );
      expect(p, {'name': 'Mali R.'});
    });

    test('phone trimmed before compare', () {
      final p = buildProfilePatch(
        initial: _initial(),
        name: 'Mali',
        phone: '  0812345678 ',
        lat: null,
        lng: null,
        label: '',
        theme: 'system',
        notificationsEnabled: true,
      );
      expect(p, isEmpty);
    });

    test('adds deliveryAddress when set for the first time', () {
      final p = buildProfilePatch(
        initial: _initial(),
        name: 'Mali',
        phone: '0812345678',
        lat: 13.7,
        lng: 100.5,
        label: 'Home',
        theme: 'system',
        notificationsEnabled: true,
      );
      expect(p, {
        'deliveryAddress': {'lat': 13.7, 'lng': 100.5, 'label': 'Home'},
      });
    });

    test('omits deliveryAddress when lat or lng is null', () {
      final p = buildProfilePatch(
        initial: _initial(),
        name: 'Mali',
        phone: '0812345678',
        lat: 13.7,
        lng: null,
        label: 'Home',
        theme: 'system',
        notificationsEnabled: true,
      );
      expect(p, isEmpty);
    });

    test('omits label key when blank', () {
      final p = buildProfilePatch(
        initial: _initial(),
        name: 'Mali',
        phone: '0812345678',
        lat: 13.7,
        lng: 100.5,
        label: '   ',
        theme: 'system',
        notificationsEnabled: true,
      );
      expect(p['deliveryAddress'], {'lat': 13.7, 'lng': 100.5});
    });

    test('skips deliveryAddress when unchanged from initial', () {
      final p = buildProfilePatch(
         initial: _initial(
          deliveryAddress: {
            'lat': 13.7,
            'lng': 100.5,
            'label': 'Home',
          },
        ),
        name: 'Mali',
        phone: '0812345678',
        lat: 13.7,
        lng: 100.5,
        label: 'Home',
        theme: 'system',
        notificationsEnabled: true,
      );
      expect(p, isEmpty);
    });

    test('emits prefs when theme changes', () {
      final p = buildProfilePatch(
        initial: _initial(),
        name: 'Mali',
        phone: '0812345678',
        lat: null,
        lng: null,
        label: '',
        theme: 'dark',
        notificationsEnabled: true,
      );
      expect(p, {
        'prefs': {'theme': 'dark', 'notificationsEnabled': true},
      });
    });

    test('emits prefs when notifications toggle flips', () {
      final p = buildProfilePatch(
        initial: _initial(prefs: {'theme': 'light', 'notificationsEnabled': true}),
        name: 'Mali',
        phone: '0812345678',
        lat: null,
        lng: null,
        label: '',
        theme: 'light',
        notificationsEnabled: false,
      );
      expect(p, {
        'prefs': {'theme': 'light', 'notificationsEnabled': false},
      });
    });

    test('combines multiple sparse changes', () {
      final p = buildProfilePatch(
        initial: _initial(),
        name: 'Mali R.',
        phone: '0900000000',
        lat: null,
        lng: null,
        label: '',
        theme: 'dark',
        notificationsEnabled: false,
      );
      expect(p, {
        'name': 'Mali R.',
        'phone': '0900000000',
        'prefs': {'theme': 'dark', 'notificationsEnabled': false},
      });
    });
  });
}
