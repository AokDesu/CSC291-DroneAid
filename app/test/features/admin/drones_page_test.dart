// Widget + unit tests for P-A-03 admin drone list.
//
// Strategy mirrors `inventory_page_test.dart`:
//   - Pure helpers (`applyDroneFilter`, `droneStatusLabel`) — exercised directly.
//   - Widget tree — override `adminDronesStreamProvider` with a fake stream,
//     wrap in a GoRouter that has the /admin/drones + /admin/drones/:id routes
//     so the tap-to-detail assertion works without booting Firebase.

import 'package:droneaid/features/admin/drones/drone.dart';
import 'package:droneaid/features/admin/drones/drone_providers.dart';
import 'package:droneaid/features/admin/drones_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('droneStatusLabel', () {
    test('maps known statuses to display strings', () {
      expect(droneStatusLabel('idle'), 'Idle');
      expect(droneStatusLabel('flying'), 'Flying');
      expect(droneStatusLabel('maintenance'), 'Maint.');
      expect(droneStatusLabel('offline'), 'Offline');
    });

    test('falls through to raw status for unknown values', () {
      expect(droneStatusLabel('charging'), 'charging');
    });
  });

  group('applyDroneFilter', () {
    final fleet = [
      _drone(id: 'a', status: 'idle'),
      _drone(id: 'b', status: 'flying'),
      _drone(id: 'c', status: 'maintenance'),
      _drone(id: 'd', status: 'offline'),
    ];

    test('empty selection returns all drones', () {
      expect(applyDroneFilter(fleet, {}).length, 4);
    });

    test('single-status filter narrows the list', () {
      final out = applyDroneFilter(fleet, {'flying'});
      expect(out.length, 1);
      expect(out.single.id, 'b');
    });

    test('multi-status filter is OR', () {
      final out = applyDroneFilter(fleet, {'idle', 'offline'});
      expect(out.map((d) => d.id).toList(), ['a', 'd']);
    });

    test('filter with no matches returns empty', () {
      expect(applyDroneFilter(fleet, {'charging'}), isEmpty);
    });
  });

  group('AdminDronesPage widgets', () {
    testWidgets('renders one card per drone with name + battery + status',
        (tester) async {
      await _pump(
        tester,
        drones: [
          _drone(id: 'drn-001', name: 'DRN-001', status: 'idle', batteryPct: 92),
          _drone(id: 'drn-002', name: 'DRN-002', status: 'flying', batteryPct: 68),
        ],
      );

      expect(find.text('DRN-001'), findsOneWidget);
      expect(find.text('DRN-002'), findsOneWidget);
      expect(find.text('92%'), findsOneWidget);
      expect(find.text('68%'), findsOneWidget);
      // Status chips show the friendly label, not the raw enum.
      expect(find.text('Idle'), findsWidgets);
      expect(find.text('Flying'), findsWidgets);
    });

    testWidgets('Flying filter chip narrows the list', (tester) async {
      await _pump(
        tester,
        drones: [
          _drone(id: 'a', name: 'DRN-001', status: 'idle'),
          _drone(id: 'b', name: 'DRN-002', status: 'flying'),
        ],
      );

      await tester.tap(find.byKey(const Key('filter-flying')));
      await tester.pumpAndSettle();

      expect(find.text('DRN-002'), findsOneWidget);
      expect(find.text('DRN-001'), findsNothing);
    });

    testWidgets('shows in-filter empty state when nothing matches',
        (tester) async {
      await _pump(
        tester,
        drones: [_drone(id: 'a', status: 'idle')],
      );

      await tester.tap(find.byKey(const Key('filter-offline')));
      await tester.pumpAndSettle();

      expect(find.text('No drones in this filter.'), findsOneWidget);
    });

    testWidgets('shows zero-fleet empty state when stream is empty',
        (tester) async {
      await _pump(tester, drones: const []);
      expect(find.text('No drones yet.'), findsOneWidget);
    });

    testWidgets('tapping a card navigates to /admin/drones/:id',
        (tester) async {
      await _pump(
        tester,
        drones: [_drone(id: 'drn-007', name: 'DRN-007', status: 'idle')],
      );

      await tester.tap(find.byKey(const Key('drone-drn-007')));
      await tester.pumpAndSettle();

      expect(find.text('detail:drn-007'), findsOneWidget);
    });

    testWidgets('shows currentFlightId badge when drone is on a flight',
        (tester) async {
      await _pump(
        tester,
        drones: [
          _drone(
            id: 'drn-008',
            name: 'DRN-008',
            status: 'flying',
            currentFlightId: 'flt-xyz',
          ),
          _drone(id: 'drn-009', name: 'DRN-009', status: 'idle'),
        ],
      );

      expect(find.byKey(const Key('drone-flight-drn-008')), findsOneWidget);
      expect(find.text('flt-xyz'), findsOneWidget);
      expect(find.byKey(const Key('drone-flight-drn-009')), findsNothing);
    });
  });
}

Drone _drone({
  String id = 'd',
  String? name,
  String status = 'idle',
  int batteryPct = 100,
  double maxPayloadKg = 6.0,
  String? currentFlightId,
}) {
  return Drone(
    id: id,
    name: name ?? id.toUpperCase(),
    status: status,
    batteryPct: batteryPct,
    baseLat: 13.74,
    baseLng: 100.54,
    maxPayloadKg: maxPayloadKg,
    currentFlightId: currentFlightId,
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required List<Drone> drones,
}) async {
  final router = GoRouter(
    initialLocation: '/admin/drones',
    routes: [
      GoRoute(
        path: '/admin/drones',
        builder: (_, __) => const AdminDronesPage(),
      ),
      GoRoute(
        path: '/admin/drones/:droneId',
        builder: (_, state) =>
            Scaffold(body: Text('detail:${state.pathParameters['droneId']}')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminDronesStreamProvider.overrideWith((ref) => Stream.value(drones)),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}
