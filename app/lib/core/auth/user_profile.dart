// Immutable view of `users/{uid}` for the client.
//
// Mirrors the document shape provisioned by `functions/src/triggers/onUserCreated.ts`
// + edited by `functions/src/callable/updateProfile.ts`.

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.nationalId,
    required this.name,
    required this.phone,
    required this.role,
    required this.locked,
    this.deliveryAddress,
    this.hubLocation,
    this.prefs,
  });

  final String uid;
  final String? nationalId;
  final String? name;
  final String? phone;
  final String role;
  final bool locked;
  final Map<String, dynamic>? deliveryAddress;
  final Map<String, dynamic>? hubLocation;
  final Map<String, dynamic>? prefs;

  bool get isAdmin => role == 'admin';

  String get theme => (prefs?['theme'] as String?) ?? 'system';
  bool get notificationsEnabled =>
      (prefs?['notificationsEnabled'] as bool?) ?? true;

  factory UserProfile.fromMap(String uid, Map<String, dynamic> data) {
    return UserProfile(
      uid: uid,
      nationalId: data['nationalId'] as String?,
      name: data['name'] as String?,
      phone: data['phone'] as String?,
      role: (data['role'] as String?) ?? 'user',
      locked: (data['locked'] as bool?) ?? false,
      deliveryAddress: (data['deliveryAddress'] as Map?)?.cast<String, dynamic>(),
      hubLocation: (data['hubLocation'] as Map?)?.cast<String, dynamic>(),
      prefs: (data['prefs'] as Map?)?.cast<String, dynamic>(),
    );
  }
}
