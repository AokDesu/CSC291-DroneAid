// Tests for P-U-03 Home / Request page + pure helpers.
//
// Strategy:
//   - Pure helpers (`cartTotalWeightKg`, `canSubmit`, `buildSubmitPayload`)
//     are exercised directly with synthetic CartState + CatalogEntry.
//   - Widget tree overrides `activeCatalogProvider`, `userProfileProvider`,
//     and `authStateProvider` so we never touch Firebase.
//   - The pin picker route requires the OSM tile network + flutter_map's
//     render pipeline, so widget tests cover the catalog rows, cart math,
//     and submit-button gating only. The pin picker itself stays manual.

import 'package:droneaid/core/auth/auth_providers.dart';
import 'package:droneaid/features/user/home_page.dart';
import 'package:droneaid/features/user/request/cart.dart';
import 'package:droneaid/features/user/request/catalog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('cartTotalWeightKg', () {
    final catalog = [
      _entry(id: 'food-kit', weightKg: 2.0),
      _entry(id: 'water-5l', weightKg: 5.0),
      _entry(id: 'blanket', weightKg: 0.5),
    ];

    test('sums qty * weightKg', () {
      const cart = CartState(lines: {'food-kit': 1, 'blanket': 3});
      expect(cartTotalWeightKg(cart, catalog), 2.0 + 1.5);
    });

    test('ignores unknown catalog ids', () {
      const cart = CartState(lines: {'ghost': 9});
      expect(cartTotalWeightKg(cart, catalog), 0);
    });

    test('empty cart → 0', () {
      expect(cartTotalWeightKg(const CartState(), catalog), 0);
    });
  });

  group('canSubmit', () {
    test('false when cart empty', () {
      expect(
        canSubmit(cart: const CartState(), totalWeightKg: 0, pinSet: true),
        isFalse,
      );
    });

    test('false when over payload', () {
      expect(
        canSubmit(
          cart: const CartState(lines: {'water-5l': 2}),
          totalWeightKg: 10,
          pinSet: true,
        ),
        isFalse,
      );
    });

    test('false when pin missing', () {
      expect(
        canSubmit(
          cart: const CartState(lines: {'food-kit': 1}),
          totalWeightKg: 2,
          pinSet: false,
        ),
        isFalse,
      );
    });

    test('true when cart non-empty, weight ≤ 6, pin set', () {
      expect(
        canSubmit(
          cart: const CartState(lines: {'food-kit': 1}),
          totalWeightKg: 2,
          pinSet: true,
        ),
        isTrue,
      );
    });
  });

  group('buildSubmitPayload', () {
    test('matches server schema; includes label when present', () {
      final payload = buildSubmitPayload(
        cart: const CartState(lines: {'food-kit': 2, 'blanket': 1}),
        pin: const DeliveryPin(lat: 13.7, lng: 100.5, label: 'Home'),
      );
      expect(payload, {
        'items': [
          {'catalogId': 'food-kit', 'qty': 2},
          {'catalogId': 'blanket', 'qty': 1},
        ],
        'deliveryAddress': {'lat': 13.7, 'lng': 100.5, 'label': 'Home'},
        'priority': 'normal',
      });
    });

    test('omits empty label', () {
      final payload = buildSubmitPayload(
        cart: const CartState(lines: {'food-kit': 1}),
        pin: const DeliveryPin(lat: 13.7, lng: 100.5, label: '   '),
      );
      expect((payload['deliveryAddress'] as Map).containsKey('label'), isFalse);
    });
  });

  group('CartNotifier', () {
    test('setQty clamps to [1, maxQtyPerLine] and removes on 0', () {
      final notifier = CartNotifier();
      notifier.setQty('food-kit', 3);
      expect(notifier.state.lines['food-kit'], 3);
      notifier.setQty('food-kit', 99);
      expect(notifier.state.lines['food-kit'], maxQtyPerLine);
      notifier.setQty('food-kit', 0);
      expect(notifier.state.lines.containsKey('food-kit'), isFalse);
    });

    test('setPin updates pin without touching lines', () {
      final notifier = CartNotifier()..setQty('food-kit', 1);
      notifier.setPin(const DeliveryPin(lat: 1, lng: 2));
      expect(notifier.state.pin?.lat, 1);
      expect(notifier.state.lines['food-kit'], 1);
    });

    test('clear resets state', () {
      final notifier = CartNotifier()
        ..setQty('food-kit', 1)
        ..setPin(const DeliveryPin(lat: 1, lng: 2));
      notifier.clear();
      expect(notifier.state.lines, isEmpty);
      expect(notifier.state.pin, isNull);
    });
  });

  group('UserHomePage widgets', () {
    testWidgets('empty catalog shows the "no supplies" copy', (tester) async {
      await _pump(tester, catalog: const []);
      expect(
        find.text('No supplies available right now. Check back soon.'),
        findsOneWidget,
      );
    });

    testWidgets('catalog rows render and inc updates qty + cart',
        (tester) async {
      await _pump(
        tester,
        catalog: [_entry(id: 'food-kit', name: 'Food Kit', weightKg: 2)],
      );
      expect(find.text('Food Kit'), findsOneWidget);

      await tester.tap(find.byKey(const Key('inc-food-kit')));
      await tester.pump();

      expect(find.text('1'), findsOneWidget);
      expect(find.text('Food Kit ×1'), findsOneWidget);
    });

    testWidgets('submit button disabled until cart + pin valid',
        (tester) async {
      await _pump(
        tester,
        catalog: [_entry(id: 'food-kit', weightKg: 2)],
      );

      final submit = find.byKey(const Key('submit-request'));
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
      expect(find.text('Add at least one item to your cart.'), findsOneWidget);
    });

    testWidgets('out-of-stock row shows label + disables the [+] button',
        (tester) async {
      await _pump(
        tester,
        catalog: [_entry(id: 'water-5l', name: 'Water 5 L', stock: 0)],
      );
      expect(find.text('Out of stock'), findsOneWidget);
      // _AddButton is an InkResponse with onTap == null when canAdd is false.
      final inc = tester.widget<InkResponse>(
        find.byKey(const Key('inc-water-5l')),
      );
      expect(inc.onTap, isNull);
    });

    testWidgets('over-payload disables submit with explanatory copy',
        (tester) async {
      await _pump(
        tester,
        catalog: [
          _entry(id: 'water-5l', name: 'Water 5 L', weightKg: 5.0, stock: 5),
        ],
      );
      await tester.tap(find.byKey(const Key('inc-water-5l')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('inc-water-5l')));
      await tester.pump();

      // Scroll the submit area into view — the page is taller after the
      // PageHeader + CategoryIconTile rows landed.
      await tester.scrollUntilVisible(
        find.byKey(const Key('submit-request')),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Total exceeds drone payload.'), findsWidgets);
    });
  });
}

CatalogEntry _entry({
  required String id,
  String? name,
  double weightKg = 1.0,
  int stock = 10,
  bool active = true,
  String? icon,
}) {
  return CatalogEntry(
    id: id,
    name: name ?? id,
    weightKg: weightKg,
    stock: stock,
    active: active,
    icon: icon,
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required List<CatalogEntry> catalog,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider
            .overrideWith((ref) => Stream<User?>.value(null)),
        userProfileProvider
            .overrideWith((ref) async => null),
        activeCatalogProvider
            .overrideWith((ref) => Stream.value(catalog)),
      ],
      child: const MaterialApp(home: UserHomePage()),
    ),
  );
  await tester.pumpAndSettle();
}
