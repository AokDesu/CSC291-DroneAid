// P-U-02 Register — Belle owns the real implementation.

import 'package:flutter/material.dart';

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register (P-U-02)')),
      body: const Center(
        child: Text('Belle: implement register per docs/09-page-flow-design.md §5 P-U-02.'),
      ),
    );
  }
}
