// FCM device registration — request permission, get token, sync to Firestore
// via updateProfile callable. Gracefully no-ops on emulator (no real device).

import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';

const _region = 'asia-southeast1';

Future<void> _doRegister() async {
  try {
    final settings = await FirebaseMessaging.instance.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;
    await FirebaseFunctions.instanceFor(region: _region)
        .httpsCallable('updateProfile')
        .call({'fcmToken': token});
  } catch (_) {
    // Emulator: messaging not available — silently skip.
  }
}

/// Watches auth state and triggers FCM registration when a user signs in.
/// Watch this provider from the app root to ensure it runs on every sign-in.
final fcmRegistrationProvider = Provider<void>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user != null) unawaited(_doRegister());
});
