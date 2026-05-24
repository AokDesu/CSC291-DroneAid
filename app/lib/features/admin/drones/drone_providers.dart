// Riverpod providers for P-A-03 admin drone list. Streams the whole fleet
// (including offline + maintenance) ordered by name.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'drone.dart';

final adminDronesStreamProvider = StreamProvider<List<Drone>>((ref) {
  final col = FirebaseFirestore.instance.collection('drones');
  return col.orderBy('name').snapshots().map(
        (snap) => snap.docs.map(Drone.fromSnap).toList(growable: false),
      );
});
