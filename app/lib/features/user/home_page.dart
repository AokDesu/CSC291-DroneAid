// P-U-03 Home / Request — Bew owns the real implementation.
// Spec: docs/09-page-flow-design.md §5 P-U-03.

import 'package:flutter/material.dart';

class UserHomePage extends StatelessWidget {
  const UserHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Request supplies (P-U-03)')),
      body: const Center(
        child: Text('Bew: implement catalog + cart + submit per §5 P-U-03.'),
      ),
    );
  }
}
