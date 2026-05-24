// Public API frozen per #23 / ADR-0003. Body filled in #26.

import 'package:flutter/material.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.status,
    this.padding,
  });

  final String status;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(status),
      padding: padding,
    );
  }
}
