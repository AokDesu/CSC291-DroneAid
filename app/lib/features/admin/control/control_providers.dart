// Riverpod providers for P-A-05 Admin Control live map.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../user/tracking/flight_provider.dart';

export '../../user/tracking/flight_provider.dart' show weatherStateProvider;

/// All flights currently in the air (enroute, delivering, or returning).
final activeFlightsProvider =
    StreamProvider.autoDispose<List<FlightDoc>>((ref) {
  ref.watch(authStateProvider);
  return FirebaseFirestore.instance
      .collection('flights')
      .where('status', whereIn: ['enroute', 'delivering', 'returning'])
      .snapshots()
      .map(
        (snap) =>
            snap.docs.map(FlightDoc.fromSnap).toList(growable: false),
      );
});
