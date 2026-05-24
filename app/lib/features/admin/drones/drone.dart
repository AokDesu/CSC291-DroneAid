// Domain model for `drones/{droneId}` docs. Mirrors the seed schema in
// functions/src/seed/seedDrones.ts and design-spec §4.

import 'package:cloud_firestore/cloud_firestore.dart';

class Drone {
  const Drone({
    required this.id,
    required this.name,
    required this.status,
    required this.batteryPct,
    required this.baseLat,
    required this.baseLng,
    required this.maxPayloadKg,
    this.currentFlightId,
    this.lastSeenAt,
  });

  final String id;
  final String name;
  final String status;
  final int batteryPct;
  final double baseLat;
  final double baseLng;
  final double maxPayloadKg;
  final String? currentFlightId;
  final DateTime? lastSeenAt;

  factory Drone.fromSnap(
    QueryDocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final data = snap.data();
    final base = (data['baseLocation'] as Map<String, dynamic>?) ?? const {};
    final ts = data['lastSeenAt'];
    return Drone(
      id: snap.id,
      name: (data['name'] as String?) ?? snap.id.toUpperCase(),
      status: (data['status'] as String?) ?? 'idle',
      batteryPct: (data['batteryPct'] as num?)?.toInt() ?? 0,
      baseLat: (base['lat'] as num?)?.toDouble() ?? 0,
      baseLng: (base['lng'] as num?)?.toDouble() ?? 0,
      maxPayloadKg: (data['maxPayloadKg'] as num?)?.toDouble() ?? 6.0,
      currentFlightId: data['currentFlightId'] as String?,
      lastSeenAt: ts is Timestamp ? ts.toDate() : null,
    );
  }
}
