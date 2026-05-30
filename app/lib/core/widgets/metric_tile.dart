// Small "LABEL / VALUE" tile used in 2×2 / 3-column metric grids (queue cards,
// tracking metrics, drone detail).

import 'package:flutter/material.dart';

import '../theme_extensions.dart';

class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    this.valueStyle,
  });

  final String label;
  final String value;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    final s = context.appText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label.toUpperCase(), style: s.metricLabel),
        const SizedBox(height: 4),
        Text(value, style: valueStyle ?? s.metricValue),
      ],
    );
  }
}
