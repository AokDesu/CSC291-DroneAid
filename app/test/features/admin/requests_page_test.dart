// Tests for P-A-01 admin requests page + helpers.

import 'package:droneaid/features/admin/requests/admin_request.dart';
import 'package:droneaid/features/admin/requests/admin_requests_provider.dart';
import 'package:droneaid/features/admin/requests_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('statusMatchesFilter', () {
    test('All accepts every status', () {
      for (final s in ['pending', 'approved', 'in_flight', 'aborted']) {
        expect(statusMatchesFilter(s, AdminRequestFilter.all), isTrue);
      }
    });

    test('Pending only matches "pending"', () {
      expect(statusMatchesFilter('pending', AdminRequestFilter.pending), isTrue);
      expect(statusMatchesFilter('approved', AdminRequestFilter.pending), isFalse);
    });

    test('Approved includes "approved" + "assigned"', () {
      expect(statusMatchesFilter('approved', AdminRequestFilter.approved), isTrue);
      expect(statusMatchesFilter('assigned', AdminRequestFilter.approved), isTrue);
    });

    test('Completed includes confirmed + delivered + completed', () {
      for (final s in ['completed', 'confirmed', 'delivered']) {
        expect(
          statusMatchesFilter(s, AdminRequestFilter.completed),
          isTrue,
          reason: s,
        );
      }
    });

    test('Aborted includes failed', () {
      expect(statusMatchesFilter('failed', AdminRequestFilter.aborted), isTrue);
      expect(statusMatchesFilter('aborted', AdminRequestFilter.aborted), isTrue);
    });
  });

  group('filterRequests', () {
    final all = [
      _req(id: 'r-pending', userId: 'u1', status: 'pending'),
      _req(id: 'r-approved', userId: 'u2', status: 'approved'),
      _req(id: 'r-flight', userId: 'u1', status: 'in_flight'),
      _req(id: 'r-cancelled', userId: 'u3', status: 'cancelled'),
    ];
    final names = {'u1': 'Mali', 'u2': 'Naree', 'u3': 'Somchai'};

    test('All + empty search returns full list', () {
      final out = filterRequests(
        all,
        filter: AdminRequestFilter.all,
        search: '',
        userNames: names,
      );
      expect(out.length, all.length);
    });

    test('Pending filter narrows to pending', () {
      final out = filterRequests(
        all,
        filter: AdminRequestFilter.pending,
        search: '',
        userNames: names,
      );
      expect(out.map((r) => r.id), ['r-pending']);
    });

    test('Search matches user name case-insensitively', () {
      final out = filterRequests(
        all,
        filter: AdminRequestFilter.all,
        search: 'MaLi',
        userNames: names,
      );
      expect(out.map((r) => r.userId), ['u1', 'u1']);
    });

    test('Search matches reqId substring', () {
      final out = filterRequests(
        all,
        filter: AdminRequestFilter.all,
        search: 'flight',
        userNames: names,
      );
      expect(out.map((r) => r.id), ['r-flight']);
    });

    test('Filter + search combine', () {
      final out = filterRequests(
        all,
        filter: AdminRequestFilter.inFlight,
        search: 'mali',
        userNames: names,
      );
      expect(out.map((r) => r.id), ['r-flight']);
    });
  });

  group('relativeAge', () {
    final now = DateTime(2026, 5, 24, 12);

    test('null → em-dash', () => expect(relativeAge(null, now: now), '—'));

    test('< 60s → Just now', () {
      expect(
        relativeAge(now.subtract(const Duration(seconds: 20)), now: now),
        'Just now',
      );
    });

    test('minutes', () {
      expect(
        relativeAge(now.subtract(const Duration(minutes: 10)), now: now),
        '10 min ago',
      );
    });

    test('yesterday', () {
      expect(
        relativeAge(now.subtract(const Duration(days: 1)), now: now),
        'Yesterday',
      );
    });
  });

  group('formatAdminItemSummary', () {
    test('empty → fallback', () {
      expect(formatAdminItemSummary(const []), '(no items)');
    });

    test('renders items in catalogId ×qty form', () {
      expect(
        formatAdminItemSummary(const [
          AdminRequestItem(catalogId: 'food-kit', qty: 2),
          AdminRequestItem(catalogId: 'blanket', qty: 1),
        ]),
        'food-kit ×2 · blanket ×1',
      );
    });
  });

  group('AdminRequestsPage widgets', () {
    testWidgets('renders all rows initially', (tester) async {
      await _pump(
        tester,
        requests: [
          _req(id: 'r-a', userId: 'u1', status: 'pending'),
          _req(id: 'r-b', userId: 'u2', status: 'in_flight'),
        ],
        userNames: const {'u1': 'Mali', 'u2': 'Naree'},
      );
      expect(find.byKey(const Key('admin-row-r-a')), findsOneWidget);
      expect(find.byKey(const Key('admin-row-r-b')), findsOneWidget);
      expect(find.text('Mali'), findsOneWidget);
      expect(find.text('Naree'), findsOneWidget);
    });

    testWidgets('selecting Pending chip narrows the list', (tester) async {
      await _pump(
        tester,
        requests: [
          _req(id: 'r-a', userId: 'u1', status: 'pending'),
          _req(id: 'r-b', userId: 'u2', status: 'in_flight'),
        ],
      );
      await tester.tap(find.byKey(const Key('chip-pending')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('admin-row-r-a')), findsOneWidget);
      expect(find.byKey(const Key('admin-row-r-b')), findsNothing);
    });

    testWidgets('search narrows by reqId substring', (tester) async {
      await _pump(
        tester,
        requests: [
          _req(id: 'aaa', userId: 'u1', status: 'pending'),
          _req(id: 'bbb', userId: 'u1', status: 'pending'),
        ],
      );
      await tester.enterText(
        find.byKey(const Key('admin-requests-search')),
        'aaa',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('admin-row-aaa')), findsOneWidget);
      expect(find.byKey(const Key('admin-row-bbb')), findsNothing);
    });

    testWidgets('empty result shows the helper text', (tester) async {
      await _pump(
        tester,
        requests: [_req(id: 'r-a', userId: 'u1', status: 'pending')],
      );
      await tester.tap(find.byKey(const Key('chip-inFlight')));
      await tester.pumpAndSettle();
      expect(find.text('No requests match this filter.'), findsOneWidget);
    });
  });
}

AdminRequest _req({
  required String id,
  required String userId,
  required String status,
  List<AdminRequestItem> items = const [
    AdminRequestItem(catalogId: 'food-kit', qty: 1),
  ],
  double totalWeightKg = 2.0,
  DateTime? createdAt,
  String? currentFlightId,
  String priority = 'normal',
}) {
  return AdminRequest(
    id: id,
    userId: userId,
    status: status,
    items: items,
    totalWeightKg: totalWeightKg,
    createdAt: createdAt ?? DateTime.now(),
    currentFlightId: currentFlightId,
    priority: priority,
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required List<AdminRequest> requests,
  Map<String, String> userNames = const {},
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminAllRequestsProvider
            .overrideWith((ref) => Stream.value(requests)),
        userNamesProvider
            .overrideWith((ref) => Stream.value(userNames)),
      ],
      child: const MaterialApp(home: AdminRequestsPage()),
    ),
  );
  await tester.pumpAndSettle();
}
