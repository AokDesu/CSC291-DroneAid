import 'package:droneaid/core/widgets/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpChip(WidgetTester tester, String status) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: StatusChip(status: status)),
      ),
    );
  }

  Color bgOf(WidgetTester tester) {
    final chip = tester.widget<Chip>(find.byType(Chip));
    return chip.backgroundColor!;
  }

  group('StatusChip', () {
    final cases = <String, Color>{
      'pending': Colors.blue,
      'approved': Colors.green,
      'rejected': Colors.red,
      'in_flight': Colors.orange,
      'completed': Colors.grey,
      'cancelled': Colors.grey,
      'aborted': Colors.red,
    };

    cases.forEach((status, expected) {
      testWidgets('$status → ${expected.toString()}', (tester) async {
        await pumpChip(tester, status);
        expect(bgOf(tester), expected);
      });
    });

    test('unknown status falls back to grey', () {
      expect(StatusChip.colorFor('totally-made-up'), Colors.grey);
    });
  });
}
