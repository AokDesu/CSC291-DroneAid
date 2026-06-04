// Map-backed AppLockStore for tests — no platform channel, runs under
// `flutter test`. Shared by the PinService and controller suites.

import 'package:droneaid/core/applock/app_lock_store.dart';

class InMemoryAppLockStore implements AppLockStore {
  InMemoryAppLockStore([Map<String, String>? seed]) : map = seed ?? {};

  final Map<String, String> map;

  @override
  Future<String?> read(String key) async => map[key];

  @override
  Future<void> write(String key, String value) async => map[key] = value;

  @override
  Future<void> delete(String key) async => map.remove(key);
}
