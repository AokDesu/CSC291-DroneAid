// Tests for P-U-04 Queue page + helpers.
//
// Strategy:
//   - Pure helpers (`bucketFor`, `relativeTime`, `formatItemSummary`) are
//     exercised directly.
//   - Widget tree overrides `myRequestsProvider`, `catalogNamesProvider`,
//     and `authStateProvider` so we never touch Firebase. Cancel button
//     visibility + tap target are asserted; the actual `cancelRequest`
//     callable is not invoked from tests (covered manually on emulator).

import 'package:droneaid/core/auth/auth_providers.dart';
import 'package:droneaid/features/user/queue_page.dart';
import 'package:droneaid/features/user/request/app_request.dart';
import 'package:droneaid/features/user/request/queue_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('bucketFor', () {
    test('pending → pending bucket', () {
      expect(bucketFor('pending'), QueueBucket.pending);
    });

    test('active states map to active bucket', () {
      for (final s in ['approved', 'assigned', 'in_flight', 'delivered']) {
        expect(bucketFor(s), QueueBucket.active, reason: s);
      }
    });

    test('terminal/historic states map to hidden bucket', () {
      for (final s in [
        'rejected',
        'cancelled',
        'failed',
        'aborted',
        'confirmed',
        'completed',
      ]) {
        expect(bucketFor(s), QueueBucket.hidden, reason: s);
      }
    });
  });

  group('relativeTime', () {
    final now = DateTime(2026, 5, 24, 12, 0, 0);

    test('null → em-dash', () {
      expect(relativeTime(null, now: now), '—');
    });

    test('< 60 s → Just now', () {
      expect(
        relativeTime(now.subtract(const Duration(seconds: 30)), now: now),
        'Just now',
      );
    });

    test('minutes', () {
      expect(
        relativeTime(now.subtract(const Duration(minutes: 7)), now: now),
        '7 min ago',
      );
    });

    test('hours', () {
      expect(
        relativeTime(now.subtract(const Duration(hours: 3)), now: now),
        '3 h ago',
      );
    });

    test('yesterday', () {
      expect(
        relativeTime(now.subtract(const Duration(days: 1)), now: now),
        'Yesterday',
      );
    });

    test('days', () {
      expect(
        relativeTime(now.subtract(const Duration(days: 4)), now: now),
        '4 d ago',
      );
    });

    test('older than a week falls back to month-day', () {
      expect(
        relativeTime(DateTime(2026, 3, 14), now: now),
        'Mar 14',
      );
    });
  });

  group('formatItemSummary', () {
    test('empty → fallback string', () {
      expect(formatItemSummary(const [], const {}), '(no items)');
    });

    test('uses catalog name when known, falls back to id otherwise', () {
      final summary = formatItemSummary(
        const [
          RequestItemLine(catalogId: 'food-kit', qty: 2),
          RequestItemLine(catalogId: 'blanket', qty: 1),
          RequestItemLine(catalogId: 'unknown-item', qty: 3),
        ],
        const {'food-kit': 'Food Kit', 'blanket': 'Blanket'},
      );
      expect(summary, 'Food Kit ×2 · Blanket ×1 · unknown-item ×3');
    });
  });

  group('QueuePage widgets', () {
    testWidgets('renders empty state when no active or pending requests',
        (tester) async {
      await _pump(tester, requests: const []);
      expect(find.text('No active requests'), findsOneWidget);
    });

    testWidgets('renders Active + Pending sections with row counts',
        (tester) async {
      final now = DateTime.now();
      await _pump(
        tester,
        requests: [
          _req(id: 'r-pending', status: 'pending', createdAt: now),
          _req(
            id: 'r-flight',
            status: 'in_flight',
            createdAt: now.subtract(const Duration(minutes: 5)),
            currentFlightId: 'F-100',
          ),
        ],
        catalogNames: const {'food-kit': 'Food Kit'},
      );

      // SectionLabel uppercases the labels for the screenshot-parity redesign.
      expect(find.text('ACTIVE'), findsOneWidget);
      expect(find.text('PENDING'), findsOneWidget);
      expect(find.byKey(const Key('queue-row-r-pending')), findsOneWidget);
      expect(find.byKey(const Key('queue-row-r-flight')), findsOneWidget);
    });

    testWidgets('Cancel button renders only on pending rows', (tester) async {
      final now = DateTime.now();
      await _pump(
        tester,
        requests: [
          _req(id: 'r-pending', status: 'pending', createdAt: now),
          _req(
            id: 'r-flight',
            status: 'in_flight',
            createdAt: now,
            currentFlightId: 'F-100',
          ),
          _req(id: 'r-approved', status: 'approved', createdAt: now),
        ],
      );

      expect(find.byKey(const Key('cancel-r-pending')), findsOneWidget);
      expect(find.byKey(const Key('cancel-r-flight')), findsNothing);
      expect(find.byKey(const Key('cancel-r-approved')), findsNothing);
    });

    testWidgets('tapping Cancel opens the confirm dialog', (tester) async {
      await _pump(
        tester,
        requests: [
          _req(id: 'r-pending', status: 'pending', createdAt: DateTime.now()),
        ],
      );

      await tester.tap(find.byKey(const Key('cancel-r-pending')));
      await tester.pumpAndSettle();

      expect(find.text('Cancel this request?'), findsOneWidget);
      expect(find.text('Keep it'), findsOneWidget);
      expect(find.text('Cancel request'), findsOneWidget);
    });

    testWidgets('terminal-state requests stay hidden from the queue',
        (tester) async {
      await _pump(
        tester,
        requests: [
          _req(id: 'r-cancelled', status: 'cancelled', createdAt: DateTime.now()),
          _req(id: 'r-completed', status: 'completed', createdAt: DateTime.now()),
        ],
      );

      expect(find.byKey(const Key('queue-row-r-cancelled')), findsNothing);
      expect(find.byKey(const Key('queue-row-r-completed')), findsNothing);
      expect(find.text('No active requests'), findsOneWidget);
    });
  });
}

AppRequest _req({
  required String id,
  required String status,
  required DateTime createdAt,
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
        // Skip the Firebase Auth dependency in `myRequestsProvider` — the
        // override below ignores the signed-in user anyway.
        authStateProvider
            .overrideWith((ref) => Stream<User?>.value(null)),
        myRequestsProvider
            .overrideWith((ref) => Stream.value(requests)),
        catalogNamesProvider
            .overrideWith((ref) => Stream.value(catalogNames)),
      ],
      child: const MaterialApp(home: QueuePage()),
    ),
  );
  await tester.pumpAndSettle();
}
