// Unit + widget tests for P-A-07 inventory page.
//
// Strategy: cover the testable boundary without booting Firebase.
//   - Pure helpers (`buildRestockPayload`, `buildCreateCatalogPayload`,
//     `itemIdPattern`) — exercised directly.
//   - Widget tree — override `adminCatalogStreamProvider` with a fake stream
//     so we can assert the low-stock pill, restock button, and add-item FAB
//     render against known data.
// The "real" callable invocation runs over Firebase Functions; we test the
// payload shape via the pure helpers since wrapping `httpsCallable` in a
// mockable seam isn't worth the bytes for a class project.

import 'package:droneaid/features/admin/inventory/catalog_item.dart';
import 'package:droneaid/features/admin/inventory/catalog_providers.dart';
import 'package:droneaid/features/admin/inventory_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CatalogItem.isLowStock', () {
    test('true when stock < 5', () {
      expect(_item(stock: 4).isLowStock, isTrue);
    });

    test('false when stock == 5', () {
      expect(_item(stock: 5).isLowStock, isFalse);
    });

    test('false when stock > 5', () {
      expect(_item(stock: 30).isLowStock, isFalse);
    });
  });

  group('buildRestockPayload', () {
    test('returns map matching server schema', () {
      final payload = buildRestockPayload(itemId: 'food-kit', qty: 10);
      expect(payload, {'itemId': 'food-kit', 'qty': 10});
    });
  });

  group('buildCreateCatalogPayload', () {
    test('includes icon when provided', () {
      final payload = buildCreateCatalogPayload(
        itemId: 'rice-bag',
        name: 'Rice Bag',
        weightKg: 1.5,
        initialStock: 20,
        icon: 'food',
      );
      expect(payload, {
        'itemId': 'rice-bag',
        'name': 'Rice Bag',
        'weightKg': 1.5,
        'initialStock': 20,
        'icon': 'food',
        'active': true,
      });
    });

    test('omits icon when blank/whitespace', () {
      final payload = buildCreateCatalogPayload(
        itemId: 'rice-bag',
        name: 'Rice Bag',
        weightKg: 1.5,
        initialStock: 20,
        icon: '   ',
      );
      expect(payload.containsKey('icon'), isFalse);
    });

    test('trims itemId, name, and icon', () {
      final payload = buildCreateCatalogPayload(
        itemId: '  rice-bag  ',
        name: '  Rice Bag  ',
        weightKg: 1.5,
        initialStock: 20,
        icon: '  food  ',
      );
      expect(payload['itemId'], 'rice-bag');
      expect(payload['name'], 'Rice Bag');
      expect(payload['icon'], 'food');
    });

    test('defaults active to true', () {
      final payload = buildCreateCatalogPayload(
        itemId: 'rice-bag',
        name: 'Rice Bag',
        weightKg: 1.5,
        initialStock: 20,
      );
      expect(payload['active'], isTrue);
    });
  });

  group('itemIdPattern', () {
    test('accepts valid kebab ids', () {
      expect(itemIdPattern.hasMatch('food-kit'), isTrue);
      expect(itemIdPattern.hasMatch('water-5l'), isTrue);
      expect(itemIdPattern.hasMatch('ab'), isTrue);
    });

    test('rejects uppercase, leading dash, single char, and too long', () {
      expect(itemIdPattern.hasMatch('Food-Kit'), isFalse);
      expect(itemIdPattern.hasMatch('-food'), isFalse);
      expect(itemIdPattern.hasMatch('a'), isFalse);
      expect(itemIdPattern.hasMatch('a' * 42), isFalse);
    });
  });

  group('AdminInventoryPage widgets', () {
    testWidgets('renders rows and low-stock pill only when stock < 5',
        (tester) async {
      await _pump(
        tester,
        items: [
          _item(id: 'food-kit', name: 'Food Kit', stock: 30),
          _item(id: 'flashlight', name: 'Flashlight', stock: 4),
        ],
      );

      expect(find.text('Food Kit'), findsOneWidget);
      expect(find.text('Flashlight'), findsOneWidget);

      // Pill only on the low-stock row.
      expect(find.byKey(const Key('low-stock-pill')), findsOneWidget);
      expect(find.text('Low stock'), findsOneWidget);
    });

    testWidgets('renders Add item FAB', (tester) async {
      await _pump(tester, items: const []);
      expect(find.text('Add item'), findsOneWidget);
    });

    testWidgets('shows empty state when catalog has zero items', (tester) async {
      await _pump(tester, items: const []);
      expect(find.text('No catalog items yet.'), findsOneWidget);
    });

    testWidgets('restock button opens dialog with quantity field + presets',
        (tester) async {
      await _pump(
        tester,
        items: [
          _item(id: 'food-kit', name: 'Food Kit', stock: 30),
        ],
      );

      await tester.tap(find.byKey(const Key('restock-food-kit')));
      await tester.pumpAndSettle();

      expect(find.text('Restock — Food Kit'), findsOneWidget);
      expect(find.byKey(const Key('restock-qty-field')), findsOneWidget);
      expect(find.text('+1'), findsOneWidget);
      expect(find.text('+5'), findsOneWidget);
      expect(find.text('+10'), findsOneWidget);
    });
  });
}

CatalogItem _item({
  String id = 'item',
  String name = 'Item',
  double weightKg = 1.0,
  int stock = 10,
  bool active = true,
  String? icon,
}) {
  return CatalogItem(
    id: id,
    name: name,
    weightKg: weightKg,
    stock: stock,
    active: active,
    icon: icon,
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required List<CatalogItem> items,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminCatalogStreamProvider.overrideWith((ref) => Stream.value(items)),
      ],
      child: const MaterialApp(home: AdminInventoryPage()),
    ),
  );
  await tester.pumpAndSettle();
}
