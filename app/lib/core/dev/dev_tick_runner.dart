// App-wide dev tick driver. Drives `devTickFlights` every 15 seconds in
// debug builds so demo flights keep moving while testing the user-side
// flow, without parking the admin on /admin/control. Production builds
// (kDebugMode == false) get a no-op provider.
//
// Server-side counterpart: `functions/src/callable/devTickFlights.ts`
// is hard-gated to FUNCTIONS_EMULATOR=true and only requires a signed-in
// user (admin OR end-user) so the same loop is callable from any session.

import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _kRegion = 'asia-southeast1';
const _kInterval = Duration(seconds: 15);

final devTickRunnerProvider = Provider<void>((ref) {
  // Production builds: do nothing. The scheduled tickFlights cron runs
  // every minute in real Firebase; we don't want the client driving it.
  if (!kDebugMode) return;

  Timer? timer;

  Future<void> tickOnce() async {
    // Tick only when a user is signed in; the callable rejects anonymous
    // calls and we don't want a noisy permission-denied loop during the
    // splash / login screens.
    if (FirebaseAuth.instance.currentUser == null) return;
    try {
      await FirebaseFunctions.instanceFor(region: _kRegion)
          .httpsCallable('devTickFlights')
          .call<Map<String, dynamic>>();
    } catch (_) {
      // Swallow transient errors. The next interval retries.
    }
  }

  timer = Timer.periodic(_kInterval, (_) => tickOnce());
  // Kick once on mount so the user doesn't have to wait the full interval.
  tickOnce();

  ref.onDispose(() => timer?.cancel());
});
