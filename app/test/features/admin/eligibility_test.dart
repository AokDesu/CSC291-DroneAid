// Tests for drone eligibility helpers (P-A-02 drone picker).

import 'package:droneaid/features/admin/drones/drone.dart';
import 'package:droneaid/features/admin/requests/eligibility.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Bangkok central baseline for distance tests.
  const baseLat = 13.7563;
  const baseLng = 100.5018;

  Drone droneFixture({
    String id = 'drn-01',
    String name = 'DRN-01',
    String status = 'idle',
    int batteryPct = 80,
    double baseLatV = baseLat,
    double baseLngV = baseLng,
    double maxPayloadKg = 6.0,
  }) {
    return Drone(
      id: id,
      name: name,
      status: status,
      batteryPct: batteryPct,
      baseLat: baseLatV,
      baseLng: baseLngV,
      maxPayloadKg: maxPayloadKg,
    );
  }

  group('haversineKm', () {
    test('zero distance for identical points', () {
      expect(
        haversineKm(lat1: 13.0, lng1: 100.0, lat2: 13.0, lng2: 100.0),
        0,
      );
    });

    test('~111 km per degree latitude near equator', () {
      final d = haversineKm(lat1: 0, lng1: 0, lat2: 1, lng2: 0);
      expect(d, closeTo(111.19, 0.5));
    });
  });

  group('eligibilityFor', () {
    test('rejects non-idle drone', () {
      final e = eligibilityFor(
        drone: droneFixture(status: 'flying'),
        totalWeightKg: 2.0,
        destLat: baseLat,
        destLng: baseLng,
      );
      expect(e.ok, isFalse);
      expect(e.reason, contains('not idle'));
    });

    test('rejects when payload exceeds drone capacity', () {
      final e = eligibilityFor(
        drone: droneFixture(maxPayloadKg: 3.0),
        totalWeightKg: 4.0,
        destLat: baseLat,
        destLng: baseLng,
      );
      expect(e.ok, isFalse);
      expect(e.reason, 'payload too small');
    });

    test('rejects below 30% battery', () {
      final e = eligibilityFor(
        drone: droneFixture(batteryPct: 25),
        totalWeightKg: 1.0,
        destLat: baseLat,
        destLng: baseLng,
      );
      expect(e.ok, isFalse);
      expect(e.reason, contains('25%'));
    });

    test('rejects when destination beyond range', () {
      // 16 km north — beyond 15 km range.
      final e = eligibilityFor(
        drone: droneFixture(),
        totalWeightKg: 1.0,
        destLat: baseLat + 16 / 111.0,
        destLng: baseLng,
      );
      expect(e.ok, isFalse);
      expect(e.reason, contains('out of range'));
    });

    test('eligible drone within all constraints', () {
      // ~1 km north of base.
      final e = eligibilityFor(
        drone: droneFixture(),
        totalWeightKg: 2.0,
        destLat: baseLat + 1 / 111.0,
        destLng: baseLng,
      );
      expect(e.ok, isTrue);
      expect(e.distanceKm, closeTo(1.0, 0.1));
      expect(e.warn, isFalse);
    });

    test('warn flag for marginal battery 30..49%', () {
      final e = eligibilityFor(
        drone: droneFixture(batteryPct: 40),
        totalWeightKg: 1.0,
        destLat: baseLat + 1 / 111.0,
        destLng: baseLng,
      );
      expect(e.ok, isTrue);
      expect(e.warn, isTrue);
    });
  });
}
