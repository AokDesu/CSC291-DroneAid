// Thin wrapper around FirebaseAuth + the Cloud Functions callables that the
// auth flow needs. Keeps the synthetic-email pattern (`<id>@drone-aid.local`)
// out of the UI layer.

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../utils/thai_id_validator.dart';

class AuthRepository {
  AuthRepository({
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  Future<UserCredential> signInWithNationalId({
    required String nationalId,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: ThaiIdValidator.toSyntheticEmail(nationalId),
      password: password,
    );
  }

  /// Creates the Auth user (which auto-signs-in) and then patches the
  /// freshly-provisioned `users/{uid}` doc with the optional profile fields
  /// via the `updateProfile` callable.
  Future<UserCredential> registerWithNationalId({
    required String nationalId,
    required String password,
    required String name,
    required String phone,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: ThaiIdValidator.toSyntheticEmail(nationalId),
      password: password,
    );
    // Best-effort profile fill. If it fails the user can still log in and
    // edit later from P-U-09.
    try {
      await _functions
          .httpsCallable('updateProfile')
          .call<Map<String, dynamic>>({'name': name, 'phone': phone});
    } catch (_) {
      // Swallow — UI surfaces "registered, finish setup later" on its own.
    }
    return cred;
  }

  Future<void> signOut() => _auth.signOut();
}
