// Public API frozen per #23 / ADR-0003. Body filled in #25.

import 'package:flutter/material.dart';

class BatteryBar extends StatelessWidget {
  const BatteryBar({
    super.key,
    required this.percent,
    this.height,
  });

  final double percent;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: LinearProgressIndicator(value: (percent / 100).clamp(0.0, 1.0)),
    );
  }
}
