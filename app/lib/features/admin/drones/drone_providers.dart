// Riverpod providers for the admin fleet pages.
//
// `adminDronesStreamProvider`     — P-A-03 list of every drone, name-sorted.
// `droneDocStreamProvider(id)`    — P-A-04 single drone doc; emits null if the
//                                    doc disappears mid-session.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'drone.dart';

final adminDronesStreamProvider = StreamProvider<List<Drone>>((ref) {
  final col = FirebaseFirestore.instance.collection('drones');
  return col.orderBy('name').snapshots().map(
        (snap) => snap.docs.map(Drone.fromSnap).toList(growable: false),
      );
});

final droneDocStreamProvider =
    StreamProvider.family<Drone?, String>((ref, droneId) {
  final ref0 = FirebaseFirestore.instance.doc('drones/$droneId');
  return ref0.snapshots().map((snap) {
    if (!snap.exists) return null;
    return Drone.fromSnap(snap);
  });
});
