// Widget smoke tests for P-U-01 Log in.
//
// Doesn't talk to FirebaseAuth — we assert UI state transitions only.
// FirebaseAuth.instance is never reached because the form short-circuits on
// invalid input.

import 'package:droneaid/features/auth/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return ProviderScope(
    child: MaterialApp(home: child),
  );
}

void main() {
  group('LoginPage', () {
    testWidgets('renders ID + password fields + Log in button', (tester) async {
      await tester.pumpWidget(_wrap(const LoginPage()));
      expect(find.text('DroneAid'), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, '13-digit national ID'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Log in'), findsOneWidget);
    });

    testWidgets('shows validation error on short national ID', (tester) async {
      await tester.pumpWidget(_wrap(const LoginPage()));
      // Enter a 12-digit ID (fails length check).
      await tester.enterText(
        find.widgetWithText(TextFormField, '13-digit national ID'),
        '110000000010',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'Demo#101',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
      await tester.pump();
      expect(find.text('Must be 13 digits'), findsOneWidget);
    });
  });
}
