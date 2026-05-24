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
    // Settle the TweenAnimationBuilder so the final color is in place.
    await tester.pumpAndSettle();
  }

  Color colorOf(WidgetTester tester) {
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    return (bar.valueColor as AlwaysStoppedAnimation<Color>).value;
  }

  group('BatteryBar', () {
    testWidgets('80% → green', (tester) async {
      await pumpBar(tester, 80);
      expect(colorOf(tester), Colors.green);
    });

    testWidgets('30% → yellow', (tester) async {
      await pumpBar(tester, 30);
      expect(colorOf(tester), Colors.yellow);
    });

    testWidgets('10% → red', (tester) async {
      await pumpBar(tester, 10);
      expect(colorOf(tester), Colors.red);
    });

    test('colorFor thresholds', () {
      expect(BatteryBar.colorFor(80), Colors.green);
      expect(BatteryBar.colorFor(51), Colors.green);
      expect(BatteryBar.colorFor(50), Colors.yellow);
      expect(BatteryBar.colorFor(21), Colors.yellow);
      expect(BatteryBar.colorFor(20), Colors.red);
      expect(BatteryBar.colorFor(0), Colors.red);
    });
  });
}
