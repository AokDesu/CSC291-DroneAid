// Pure drone-eligibility helpers for the P-A-02 drone picker.
// Mirrors `functions/src/callable/approveRequest.ts` so the client-side
// filter shows the same outcome the server would return on submit.

import 'dart:math';

import '../drones/drone.dart';

/// Server-side constants from `approveRequest.ts`.
const droneRangeKm = 15.0;
const droneMinBatteryPct = 30;

class DroneEligibility {
  const DroneEligibility({
    required this.ok,
    this.distanceKm,
    this.reason,
    this.warn = false,
  });

  final bool ok;
  final double? distanceKm;

  /// Single-sentence rejection reason when [ok] is false.
  final String? reason;

  /// True when [ok] is true but the drone is at marginal battery (< 50%).
  /// Server still accepts; UI shows an amber warning.
  final bool warn;
}

/// Great-circle distance in kilometers between two lat/lng pairs.
double haversineKm({
  required double lat1,
  required double lng1,
  required double lat2,
  required double lng2,
}) {
  const r = 6371.0;
  final dLat = _toRad(lat2 - lat1);
  final dLng = _toRad(lng2 - lng1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_toRad(lat1)) *
          cos(_toRad(lat2)) *
          sin(dLng / 2) *
          sin(dLng / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}

double _toRad(double deg) => deg * pi / 180.0;

/// Compute eligibility for a single drone against a request's total weight
/// and delivery destination. Mirrors the server-side filter in
/// `approveRequest.ts`.
DroneEligibility eligibilityFor({
  required Drone drone,
  required double totalWeightKg,
  required double destLat,
  required double destLng,
}) {
  if (drone.status != 'idle') {
    return DroneEligibility(ok: false, reason: '${drone.status}, not idle');
  }
  if (drone.maxPayloadKg < totalWeightKg) {
    return const DroneEligibility(ok: false, reason: 'payload too small');
  }
  if (drone.batteryPct < droneMinBatteryPct) {
    return DroneEligibility(
      ok: false,
      reason: 'battery ${drone.batteryPct}% < $droneMinBatteryPct%',
    );
  }
  final dist = haversineKm(
    lat1: drone.baseLat,
    lng1: drone.baseLng,
    lat2: destLat,
    lng2: destLng,
  );
  if (dist > droneRangeKm) {
    return DroneEligibility(
      ok: false,
      reason: 'out of range (${dist.toStringAsFixed(1)} km)',
      distanceKm: dist,
    );
  }
  return DroneEligibility(
    ok: true,
    distanceKm: dist,
    warn: drone.batteryPct < 50,
  );
}
