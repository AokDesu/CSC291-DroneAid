// Public API frozen per #23 / ADR-0003.

import 'package:flutter/material.dart';

class BatteryBar extends StatelessWidget {
  const BatteryBar({
    super.key,
    required this.percent,
    this.height,
  });

  final double percent;
  final double? height;

  static Color colorFor(double p) {
    if (p > 50) return Colors.green;
    if (p > 20) return Colors.yellow;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final target = percent.clamp(0.0, 100.0);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: target),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      builder: (context, value, _) {
        return SizedBox(
          height: height,
          child: LinearProgressIndicator(
            value: value / 100,
            valueColor: AlwaysStoppedAnimation<Color>(colorFor(value)),
          ),
        );
      },
    );
  }
}
