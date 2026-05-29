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
  testWidgets('Create account button is disabled until form valid',
      (tester) async {
    await tester.pumpWidget(_wrap(const RegisterPage()));

    Finder createBtn() => find.widgetWithText(FilledButton, 'Create account');
    expect(tester.widget<FilledButton>(createBtn()).onPressed, isNull);

    // Fill the required fields. Phone is optional now.
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
      find.widgetWithText(TextFormField, 'Password'),
      'StrongP@ss',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm password'),
      'StrongP@ss',
    );
    await tester.pump();
    // No terms checkbox gate any more — form should be submittable now.
    expect(tester.widget<FilledButton>(createBtn()).onPressed, isNotNull);
  });
}
