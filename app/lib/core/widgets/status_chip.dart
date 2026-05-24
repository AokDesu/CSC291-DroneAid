// Public API frozen per #23 / ADR-0003.

import 'package:flutter/material.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.status,
    this.padding,
  });

  final String status;
  final EdgeInsets? padding;

  static Color colorFor(String status) {
    switch (status) {
      case 'pending':
        return Colors.blue;
      case 'approved':
        return Colors.green;
      case 'rejected':
      case 'aborted':
        return Colors.red;
      case 'in_flight':
        return Colors.orange;
      case 'completed':
      case 'cancelled':
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = colorFor(status);
    final fg = ThemeData.estimateBrightnessForColor(bg) == Brightness.dark
        ? Colors.white
        : Colors.black87;
    return Chip(
      label: Text(status, style: TextStyle(color: fg)),
      backgroundColor: bg,
      padding: padding,
    );
  }
}
