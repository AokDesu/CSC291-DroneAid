// Riverpod provider for the singleton `weather/current` Firestore doc.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'weather.dart';

final weatherStreamProvider = StreamProvider<Weather>((ref) {
  final ref0 = FirebaseFirestore.instance.doc('weather/current');
  return ref0.snapshots().map((snap) {
    if (!snap.exists) {
      return const Weather(state: 'clear');
    }
    return Weather.fromSnap(snap);
  });
});
