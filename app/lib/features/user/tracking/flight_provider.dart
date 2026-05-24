// Riverpod providers + domain model for flights/{flightId}.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

class FlightDoc {
  const FlightDoc({
    required this.id,
    required this.requestId,
    required this.userId,
    required this.origin,
    required this.destination,
    required this.takeoffAt,
    required this.etaAt,
    required this.speedKmh,
    required this.weatherModifier,
    required this.batteryAtTakeoff,
    required this.status,
    this.failureType,
  });

  final String id;
  final String requestId;
  final String userId;
  final LatLng origin;
  final LatLng destination;
  final DateTime takeoffAt;
  final DateTime etaAt;
  final double speedKmh;
  final double weatherModifier;
  final double batteryAtTakeoff;
  final String status;
  final String? failureType;

  factory FlightDoc.fromSnap(DocumentSnapshot<Map<String, dynamic>> snap) {
    final d = snap.data() ?? {};
    final orig = d['origin'] as Map<String, dynamic>? ?? {};
    final dest = d['destination'] as Map<String, dynamic>? ?? {};
    return FlightDoc(
      id: snap.id,
      requestId: (d['requestId'] as String?) ?? '',
      userId: (d['userId'] as String?) ?? '',
      origin: LatLng(
        (orig['lat'] as num?)?.toDouble() ?? 0,
        (orig['lng'] as num?)?.toDouble() ?? 0,
      ),
      destination: LatLng(
        (dest['lat'] as num?)?.toDouble() ?? 0,
        (dest['lng'] as num?)?.toDouble() ?? 0,
      ),
      takeoffAt: (d['takeoffAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      etaAt: (d['etaAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      speedKmh: (d['speedKmh'] as num?)?.toDouble() ?? 15.0,
      weatherModifier:
          (d['weatherModifierAtTakeoff'] as num?)?.toDouble() ?? 1.0,
      batteryAtTakeoff: (d['batteryAtTakeoff'] as num?)?.toDouble() ?? 100.0,
      status: (d['status'] as String?) ?? 'enroute',
      failureType: d['failureType'] as String?,
    );
  }
}

/// Streams a single flight doc. Emits null when doc does not exist.
/// Permission errors (wrong owner) surface as AsyncError in the provider.
final flightStreamProvider =
    StreamProvider.family<FlightDoc?, String>((ref, flightId) {
  return FirebaseFirestore.instance
      .doc('flights/$flightId')
      .snapshots()
      .map((snap) => snap.exists ? FlightDoc.fromSnap(snap) : null);
});

/// Current weather state ("clear" | "rain" | "storm") from weather/current.
final weatherStateProvider = StreamProvider<String>((ref) {
  return FirebaseFirestore.instance
      .doc('weather/current')
      .snapshots()
      .map((s) => (s.data()?['state'] as String?) ?? 'clear');
});
