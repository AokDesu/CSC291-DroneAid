// Tests for P-U-07 History page + helpers.
//
// Reuses fakes for `myRequestsProvider` / `catalogNamesProvider` /
// `authStateProvider` (same shape as queue_page_test.dart) so we never
// boot Firebase.

import 'package:droneaid/core/auth/auth_providers.dart';
import 'package:droneaid/features/user/history_page.dart';
import 'package:droneaid/features/user/request/app_request.dart';
import 'package:droneaid/features/user/request/queue_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('groupByDay', () {
    test('drops requests with null createdAt', () {
      final r = _req(id: 'r1', status: 'completed', createdAt: null);
      expect(groupByDay([r]), isEmpty);
    });

    test('groups requests by calendar day, newest day first', () {
      final d1 = DateTime(2026, 6, 4, 10, 0);
      final d2 = DateTime(2026, 6, 4, 22, 30);
      final d3 = DateTime(2026, 6, 3, 8, 15);
      final result = groupByDay([
        _req(id: 'a', status: 'completed', createdAt: d2),
        _req(id: 'b', status: 'cancelled', createdAt: d1),
        _req(id: 'c', status: 'rejected', createdAt: d3),
      ]);
      expect(result.length, 2);
      expect(result.first.key, DateTime(2026, 6, 4));
      expect(result.first.value.map((r) => r.id).toList(), ['a', 'b']);
      expect(result.last.key, DateTime(2026, 6, 3));
      expect(result.last.value.map((r) => r.id).toList(), ['c']);
    });
  });

  group('formatDayHeader', () {
    test('weekday + month + day', () {
      expect(formatDayHeader(DateTime(2026, 6, 4)), 'Thu, Jun 4');
      expect(formatDayHeader(DateTime(2026, 1, 1)), 'Thu, Jan 1');
    });
  });

  group('HistoryPage widgets', () {
    testWidgets('renders empty state when no terminal-state requests',
        (tester) async {
      await _pump(tester, requests: const []);
      expect(find.text('No past deliveries yet'), findsOneWidget);
    });

    testWidgets('only hidden-bucket requests show; active/pending hidden',
        (tester) async {
      final now = DateTime(2026, 6, 4, 12);
      await _pump(
        tester,
        requests: [
          _req(id: 'r-pending', status: 'pending', createdAt: now),
          _req(id: 'r-flight', status: 'in_flight', createdAt: now),
          _req(id: 'r-done', status: 'completed', createdAt: now),
          _req(id: 'r-cancelled', status: 'cancelled', createdAt: now),
        ],
        catalogNames: const {'food-kit': 'Food Kit'},
      );

      expect(find.byKey(const Key('history-row-r-done')), findsOneWidget);
      expect(find.byKey(const Key('history-row-r-cancelled')), findsOneWidget);
      expect(find.byKey(const Key('history-row-r-pending')), findsNothing);
      expect(find.byKey(const Key('history-row-r-flight')), findsNothing);
    });

    testWidgets('groups rows under a day heading', (tester) async {
      await _pump(
        tester,
        requests: [
          _req(
            id: 'r-done',
            status: 'completed',
            createdAt: DateTime(2026, 6, 4, 12),
          ),
        ],
      );
      // SectionLabel uppercases the day header in the screenshot-parity redesign.
      expect(find.text('THU, JUN 4'), findsOneWidget);
    });

    testWidgets('tapping a row opens the detail sheet', (tester) async {
      await _pump(
        tester,
        requests: [
          _req(
            id: 'r-done',
            status: 'completed',
            createdAt: DateTime(2026, 6, 4, 12),
            currentFlightId: 'F-200',
          ),
        ],
      );
      await tester.tap(find.byKey(const Key('history-row-r-done')));
      await tester.pumpAndSettle();

      expect(find.text('Items'), findsOneWidget);
      expect(find.text('Total weight'), findsOneWidget);
      expect(find.text('Submitted'), findsOneWidget);
      expect(find.text('Last flight'), findsOneWidget);
      expect(find.text('F-200'), findsOneWidget);
    });
  });
}

AppRequest _req({
  required String id,
  required String status,
  required DateTime? createdAt,
  String userId = 'demo-uid',
  List<RequestItemLine> items = const [
    RequestItemLine(catalogId: 'food-kit', qty: 1),
  ],
  double totalWeightKg = 2.0,
  String? currentFlightId,
}) {
  return AppRequest(
    id: id,
    userId: userId,
    status: status,
    items: items,
    totalWeightKg: totalWeightKg,
    createdAt: createdAt,
    currentFlightId: currentFlightId,
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required List<AppRequest> requests,
  Map<String, String> catalogNames = const {},
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider
            .overrideWith((ref) => Stream<User?>.value(null)),
        myRequestsProvider
            .overrideWith((ref) => Stream.value(requests)),
        catalogNamesProvider
            .overrideWith((ref) => Stream.value(catalogNames)),
      ],
      child: const MaterialApp(home: HistoryPage()),
    ),
  );
  await tester.pumpAndSettle();
}
