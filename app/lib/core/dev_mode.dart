// Compile-time gate for developer-only UI surfaces (demo creds card on
// the login page, "Tick now" FAB on the admin Control page, etc.).
//
// True when:
//   - the build is debug (kDebugMode), AND
//   - the dev did NOT pass `--dart-define=USER_MODE=true`.
//
// Use this for any UI that should hide during a user-acceptance test even
// while running a normal `flutter run` debug build.
//
// Backend-only debug switches (emulator wiring, Crashlytics override) stay
// on plain `kDebugMode` — those are infrastructure, not user-visible.

import 'package:flutter/foundation.dart' show kDebugMode;

const kShowDevSurfaces = kDebugMode &&
    !bool.fromEnvironment('USER_MODE', defaultValue: false);
