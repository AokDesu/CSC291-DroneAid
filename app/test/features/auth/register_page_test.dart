// Widget smoke test for P-U-02 Create an account.

import 'package:droneaid/features/auth/register_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return ProviderScope(
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('Create account button is disabled until form valid + terms ticked',
      (tester) async {
    await tester.pumpWidget(_wrap(const RegisterPage()));

    Finder createBtn() => find.widgetWithText(FilledButton, 'Create account');
    expect(tester.widget<FilledButton>(createBtn()).onPressed, isNull);

    // Fill valid fields but leave terms unchecked.
    // 1100000000101 is the seeded "Mali" demo account — passes the Thai-ID
    // checksum.
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Full name'),
      'New User',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '13-digit national ID'),
      // Checksum-valid synthetic ID: digits[0..11] sum × weights = 36;
      // (11 - 36%11) % 10 = 8 → check digit = 8.
      '1100100000018',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Phone (e.g. +66 81 ...)'),
      '+66811112222',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'StrongP@ss',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm password'),
      'StrongP@ss',
    );
    await tester.pump();
    expect(
      tester.widget<FilledButton>(createBtn()).onPressed,
      isNull,
      reason: 'terms checkbox not yet ticked',
    );

    // Tick the terms.
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(tester.widget<FilledButton>(createBtn()).onPressed, isNotNull);
  });
}
