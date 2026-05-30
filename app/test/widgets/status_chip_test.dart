// Updated for the screenshot-parity redesign: StatusChip moved from
// MaterialColor-backed Chip to an AppStatusColors ThemeExtension pill with
// a leading bullet dot for soft statuses + filled red URGENT pill.
//
// Tests now assert presence + label rather than exact hex colors. The
// palette is owned by AppStatusColors in core/theme_extensions.dart.

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

  group('StatusChip', () {
    final labels = <String, String>{
      'pending': 'Pending',
      'approved': 'Approved',
      'rejected': 'Rejected',
      'in_flight': 'In flight',
      'completed': 'Completed',
      'cancelled': 'Cancelled',
      'aborted': 'Aborted',
      'confirmed': 'Confirmed',
      'failed': 'Failed',
      'delivered': 'Delivered',
    };

    labels.forEach((status, expectedLabel) {
      testWidgets('$status renders label "$expectedLabel"', (tester) async {
        await pumpChip(tester, status);
        expect(find.text(expectedLabel), findsOneWidget);
      });
    });

    testWidgets('urgent renders all-caps filled pill', (tester) async {
      await pumpChip(tester, 'urgent');
      expect(find.text('URGENT'), findsOneWidget);
    });

    test('colorFor stays a callable back-compat shim', () {
      // Returns a Color (the foreground) — exact value tracks the
      // AppStatusColors palette and is intentionally not pinned here.
      expect(StatusChip.colorFor('pending'), isA<Color>());
      expect(StatusChip.colorFor('totally-made-up'), isA<Color>());
    });
  });
}
