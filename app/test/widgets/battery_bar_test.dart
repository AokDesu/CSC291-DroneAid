// Updated for the screenshot-parity redesign: BatteryBar now uses fixed
// brand hexes (mint / amber / coral) instead of Material primaries. We
// assert threshold equivalence (same color at the boundary) rather than
// pinning exact RGB values, so a future palette tweak doesn't churn tests.

import 'package:droneaid/core/widgets/battery_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpBar(WidgetTester tester, double percent) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BatteryBar(percent: percent)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Color colorOf(WidgetTester tester) {
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    return (bar.valueColor as AlwaysStoppedAnimation<Color>).value;
  }

  group('BatteryBar', () {
    testWidgets('80% picks the high-battery color', (tester) async {
      await pumpBar(tester, 80);
      expect(colorOf(tester), BatteryBar.colorFor(80));
    });

    testWidgets('30% picks the mid-battery color', (tester) async {
      await pumpBar(tester, 30);
      expect(colorOf(tester), BatteryBar.colorFor(30));
    });

    testWidgets('10% picks the low-battery color', (tester) async {
      await pumpBar(tester, 10);
      expect(colorOf(tester), BatteryBar.colorFor(10));
    });

    test('colorFor thresholds', () {
      // Three distinct bands: >50 (high), 20<x<=50 (mid), <=20 (low).
      final high = BatteryBar.colorFor(80);
      final mid = BatteryBar.colorFor(30);
      final low = BatteryBar.colorFor(10);

      expect(high, isNot(equals(mid)));
      expect(mid, isNot(equals(low)));
      expect(high, isNot(equals(low)));

      expect(BatteryBar.colorFor(51), high);
      expect(BatteryBar.colorFor(50), mid);
      expect(BatteryBar.colorFor(21), mid);
      expect(BatteryBar.colorFor(20), low);
      expect(BatteryBar.colorFor(0), low);
    });
  });
}
