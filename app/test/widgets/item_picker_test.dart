import 'package:droneaid/core/widgets/item_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const items = [
    CatalogItem(id: 'water', name: 'Water', unit: '1L bottle', stockQty: 3),
    CatalogItem(id: 'rice', name: 'Rice', unit: '1kg bag'),
  ];

  Future<void> pumpPicker(
    WidgetTester tester,
    ValueChanged<List<CartLine>> onChanged,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ItemPicker(items: items, onChanged: onChanged),
        ),
      ),
    );
  }

  group('ItemPicker', () {
    testWidgets('tapping + emits a CartLine with qty 1', (tester) async {
      List<CartLine>? last;
      await pumpPicker(tester, (lines) => last = lines);

      // First row's add button is the first Icons.add in the tree.
      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pump();

      expect(last, isNotNull);
      expect(last!.length, 1);
      expect(last!.first.itemId, 'water');
      expect(last!.first.qty, 1);
    });

    testWidgets('tapping − back to zero removes the line', (tester) async {
      List<CartLine>? last;
      await pumpPicker(tester, (lines) => last = lines);

      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pump();
      await tester.tap(find.byIcon(Icons.remove).first);
      await tester.pump();

      expect(last, isNotNull);
      expect(last!.isEmpty, isTrue);
    });

    testWidgets('stockQty caps the add button', (tester) async {
      List<CartLine>? last;
      await pumpPicker(tester, (lines) => last = lines);

      // Water has stockQty: 3 — tap + four times, fourth should be a no-op.
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byIcon(Icons.add).first, warnIfMissed: false);
        await tester.pump();
      }

      expect(last!.first.qty, 3);
    });
  });
}
