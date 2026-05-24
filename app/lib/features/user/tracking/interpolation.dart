// Pure math for client-side flight interpolation.
// Mirrors functions/src/lib/sim.ts snapshot() — keep in sync if sim changes.
// No Flutter/Firestore imports: unit-testable in isolation.

import 'dart:math';

import 'package:latlong2/latlong.dart';

const _batteryDrainPerKm = 1.5;
const _earthRadiusKm = 6371.0;

/// Haversine distance in kilometres. Mirrors geo.ts haversineKm().
double haversineKm(LatLng a, LatLng b) {
  final dLat = _rad(b.latitude - a.latitude);
  final dLon = _rad(b.longitude - a.longitude);
  final h = sin(dLat / 2) * sin(dLat / 2) +
      cos(_rad(a.latitude)) * cos(_rad(b.latitude)) * sin(dLon / 2) * sin(dLon / 2);
  return 2 * _earthRadiusKm * asin(sqrt(h.clamp(0.0, 1.0)));
}

double _rad(double deg) => deg * pi / 180;

/// Linear interpolation between two LatLng coordinates.
LatLng lerpLatLng(LatLng a, LatLng b, double t) => LatLng(
      a.latitude + (b.latitude - a.latitude) * t,
      a.longitude + (b.longitude - a.longitude) * t,
    );

/// Mirrors sim.ts snapshot(). Returns progress [0–1] and current battery %.
({double progress, double battery}) flightSnapshot({
  required LatLng origin,
  required LatLng destination,
  required DateTime takeoffAt,
  required double speedKmh,
  required double weatherModifier,
  required double batteryAtTakeoff,
  required DateTime now,
}) {
  final distKm = haversineKm(origin, destination);
  final effectiveKmh = max(1.0, speedKmh * weatherModifier);
  final elapsedHours =
      max(0.0, now.difference(takeoffAt).inMilliseconds / 3600000.0);
  final traveledKm = min(distKm, elapsedHours * effectiveKmh);
  final progress = distKm == 0 ? 1.0 : traveledKm / distKm;
  final battery =
      max(0.0, batteryAtTakeoff - traveledKm * _batteryDrainPerKm);
  return (progress: progress.clamp(0.0, 1.0), battery: battery);
}

/// Remaining time to ETA, floored at zero.
Duration etaRemaining(DateTime etaAt, DateTime now) {
  final d = etaAt.difference(now);
  return d.isNegative ? Duration.zero : d;
}

/// Compute drone screen position from flight status + interpolation progress.
LatLng dronePosition({
  required String status,
  required LatLng origin,
  required LatLng destination,
  required double progress,
}) =>
    switch (status) {
      'enroute' => lerpLatLng(origin, destination, progress),
      'delivering' || 'completed' => destination,
      'returning' => lerpLatLng(destination, origin, progress),
      _ => destination, // aborted / failed — last known position
    };

/// Human-friendly ETA string: "in 5 min", "< 1 min", "Arriving…".
String etaLabel(Duration remaining) {
  if (remaining == Duration.zero) return 'Arriving…';
  final mins = remaining.inSeconds < 60
      ? '< 1 min'
      : '${remaining.inMinutes} min';
  return 'in $mins';
}

/// Weather label from the modifier stored on the flight doc.
String weatherLabel(double modifier) => switch (modifier) {
      >= 0.95 => 'Clear',
      >= 0.75 => 'Rain',
      _ => 'Storm',
    };
