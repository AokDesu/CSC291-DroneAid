// P-U-01 Login — Belle owns the real implementation.
// Spec: docs/09-page-flow-design.md §5 P-U-01.
//
// This is a placeholder shell so the router resolves and the app compiles.

import 'package:flutter/material.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log in (P-U-01)')),
      body: const Center(
        child: Text('Belle: implement login per docs/09-page-flow-design.md §5 P-U-01.'),
      ),
    );
  }
}
