// Riverpod providers for P-U-04 Queue.
//
// Spec §5 P-U-04 calls this `myRequestsProvider`. Query: all docs in
// `requests/` where `userId == auth.uid`, ordered by createdAt desc. The
// page itself does the bucket split (Active vs Pending vs Hidden) on the
// client — composite index for that filter already exists
// (firestore.indexes.json: userId asc, createdAt desc).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import 'app_request.dart';

/// All requests owned by the signed-in user (any status), newest first.
/// Emits an empty list when the user is signed out so the page can render
/// its empty state without throwing.
final myRequestsProvider = StreamProvider<List<AppRequest>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value(const []);
  final col = FirebaseFirestore.instance.collection('requests');
  return col
      .where('userId', isEqualTo: user.uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(
        (snap) => snap.docs.map(AppRequest.fromSnap).toList(growable: false),
      );
});

/// `catalogId -> name` lookup for the queue rows. Reading `catalog/` is
/// allowed for any signed-in user (firestore.rules). Falls back to the raw
/// catalogId when a name is missing.
final catalogNamesProvider = StreamProvider<Map<String, String>>((ref) {
  final col = FirebaseFirestore.instance.collection('catalog');
  return col.snapshots().map(
        (snap) => <String, String>{
          for (final d in snap.docs)
            d.id: (d.data()['name'] as String?) ?? d.id,
        },
      );
});
