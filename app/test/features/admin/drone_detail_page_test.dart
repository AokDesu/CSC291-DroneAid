// Widget + unit tests for P-A-04 admin drone detail page.

import 'package:droneaid/features/admin/drones/drone.dart';
import 'package:droneaid/features/admin/drones/drone_detail_page.dart';
import 'package:droneaid/features/admin/drones/drone_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('relativeTime', () {
    final now = DateTime.utc(2026, 5, 24, 12, 0, 0);

    test('returns em-dash for null', () {
      expect(relativeTime(null, now: now), '—');
    });

    test('"just now" for sub-5s', () {
      expect(
        relativeTime(now.subtract(const Duration(seconds: 2)), now: now),
        'just now',
      );
    });

    test('seconds bucket', () {
      expect(
        relativeTime(now.subtract(const Duration(seconds: 30)), now: now),
        '30s ago',
      );
    });

    test('minutes bucket', () {
      expect(
        relativeTime(now.subtract(const Duration(minutes: 7)), now: now),
        '7m ago',
      );
    });

    test('hours bucket', () {
      expect(
        relativeTime(now.subtract(const Duration(hours: 3)), now: now),
        '3h ago',
      );
    });

    test('days bucket', () {
      expect(
        relativeTime(now.subtract(const Duration(days: 2, hours: 5)), now: now),
        '2d ago',
      );
    });

    test('future timestamp clamps to "just now"', () {
      expect(
        relativeTime(now.add(const Duration(seconds: 10)), now: now),
        'just now',
      );
    });
  });

  group('nextMaintenanceMode', () {
    test('idle → maintenance', () {
      expect(nextMaintenanceMode('idle'), 'maintenance');
    });
    test('offline → maintenance', () {
      expect(nextMaintenanceMode('offline'), 'maintenance');
    });
    test('maintenance → idle (end)', () {
      expect(nextMaintenanceMode('maintenance'), 'idle');
    });
    test('flying → null (blocked)', () {
      expect(nextMaintenanceMode('flying'), isNull);
    });
  });

  group('nextOfflineMode', () {
    test('idle → offline', () {
      expect(nextOfflineMode('idle'), 'offline');
    });
    test('maintenance → offline', () {
      expect(nextOfflineMode('maintenance'), 'offline');
    });
    test('offline → idle (bring online)', () {
      expect(nextOfflineMode('offline'), 'idle');
    });
    test('flying → null (blocked)', () {
      expect(nextOfflineMode('flying'), isNull);
    });
  });

  group('AdminDroneDetailPage widgets', () {
    testWidgets('renders telemetry fields for an idle drone', (tester) async {
      await _pump(tester, drone: _drone(id: 'drn-001', batteryPct: 92));
      expect(find.text('DRN-001'), findsWidgets);
      expect(find.byKey(const Key('drone-detail-battery')), findsOneWidget);
      expect(find.text('92%'), findsOneWidget);
      expect(find.text('max 6.0 kg'), findsOneWidget);
      expect(find.text('13.7400, 100.5400'), findsOneWidget);
    });

    testWidgets('flying drone disables both action buttons and shows hint',
        (tester) async {
      await _pump(tester, drone: _drone(id: 'drn-002', status: 'flying'));

      expect(
        find.byKey(const Key('drone-detail-flying-hint')),
        findsOneWidget,
      );

      final maint = tester.widget<OutlinedButton>(
        find.byKey(const Key('drone-detail-maintenance')),
      );
      expect(maint.onPressed, isNull);

      final offline = tester.widget<OutlinedButton>(
        find.byKey(const Key('drone-detail-take-offline')),
      );
      expect(offline.onPressed, isNull);
    });

    testWidgets('idle drone enables actions; Maintenance opens confirm dialog',
        (tester) async {
      await _pump(tester, drone: _drone(id: 'drn-003', status: 'idle'));

      await tester.tap(find.byKey(const Key('drone-detail-maintenance')));
      await tester.pumpAndSettle();

      expect(find.text('Maintenance — DRN-003?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('maintenance drone shows "End maintenance" label',
        (tester) async {
      await _pump(tester, drone: _drone(id: 'drn-004', status: 'maintenance'));
      expect(find.text('End maintenance'), findsOneWidget);
    });

    testWidgets('shows "Drone not found." when stream emits null',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            droneDocStreamProvider('drn-ghost')
                .overrideWith((ref) => Stream.value(null)),
          ],
          child: const MaterialApp(
            home: AdminDroneDetailPage(droneId: 'drn-ghost'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Drone not found.'), findsOneWidget);
    });
  });
}

Drone _drone({
  String id = 'd',
  String? name,
  String status = 'idle',
  int batteryPct = 100,
  double maxPayloadKg = 6.0,
  double baseLat = 13.74,
  double baseLng = 100.54,
}) {
  return Drone(
    id: id,
    name: name ?? id.toUpperCase(),
    status: status,
    batteryPct: batteryPct,
    baseLat: baseLat,
    baseLng: baseLng,
    maxPayloadKg: maxPayloadKg,
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required Drone drone,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        droneDocStreamProvider(drone.id)
            .overrideWith((ref) => Stream.value(drone)),
      ],
      child: MaterialApp(
        home: AdminDroneDetailPage(droneId: drone.id),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
