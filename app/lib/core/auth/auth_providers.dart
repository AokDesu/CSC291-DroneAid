// Riverpod providers for auth state + profile.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_repository.dart';
import 'user_profile.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

/// Stream of the currently signed-in Firebase user (`null` when signed out).
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// `users/{uid}` doc as a [UserProfile]. Retries up to ~4.4 s to tolerate the
/// `onUserCreated` Auth trigger latency right after sign-up.
///
/// autoDispose so the cache drops the instant no widget listens — prevents
/// the previous role's profile leaking into the next sign-in window.
final userProfileProvider = FutureProvider.autoDispose<UserProfile?>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;

  final ref0 = FirebaseFirestore.instance.doc('users/${user.uid}');
  const backoffsMs = [200, 400, 800, 1200, 1800];
  for (final delay in backoffsMs) {
    final snap = await ref0.get();
    if (snap.exists) return UserProfile.fromMap(user.uid, snap.data()!);
    await Future.delayed(Duration(milliseconds: delay));
  }
  final snap = await ref0.get();
  if (!snap.exists) {
    throw StateError(
      'users/${user.uid} was not provisioned after sign-in. '
      'Check the onUserCreated trigger.',
    );
  }
  return UserProfile.fromMap(user.uid, snap.data()!);
});
