// P-A-01 Admin Requests list — Bew owns the real implementation.
// Spec: docs/09-page-flow-design.md §6 P-A-01.

import 'package:flutter/material.dart';

class AdminRequestsPage extends StatelessWidget {
  const AdminRequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Requests (P-A-01)')),
      body: const Center(
        child: Text('Bew: implement requests list per §6 P-A-01.'),
      ),
    );
  }
}
