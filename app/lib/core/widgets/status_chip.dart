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
      // ── Active progression ───────────────────────────────────────
      case 'pending':
        return Colors.blue;
      case 'approved':
        return Colors.teal;
      case 'assigned':
        return Colors.cyan;
      case 'in_flight':
      case 'enroute':
      case 'delivering':
      case 'returning':
        return Colors.orange;
      case 'delivered':
        return Colors.amber.shade700;

      // ── Success terminal ─────────────────────────────────────────
      case 'confirmed':
        return Colors.green.shade700;
      case 'completed':
        return Colors.green;

      // ── Failure terminal ─────────────────────────────────────────
      case 'rejected':
        return Colors.red;
      case 'aborted':
        return Colors.red.shade700;
      case 'failed':
        return Colors.brown;

      // ── Neutral terminal ─────────────────────────────────────────
      case 'cancelled':
        return Colors.blueGrey;

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
