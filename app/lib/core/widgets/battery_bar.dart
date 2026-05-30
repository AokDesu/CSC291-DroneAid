// Slim battery gauge. Spec C-03.
// Public API frozen per #23 / ADR-0003: `percent` + `height` props unchanged.

import 'package:flutter/material.dart';

import '../tokens.dart';

class BatteryBar extends StatelessWidget {
  const BatteryBar({
    super.key,
    required this.percent,
    this.height,
  });

  final double percent;
  final double? height;

  static Color colorFor(double p) {
    if (p > 50) return const Color(0xFF2D8C7F);
    if (p > 20) return const Color(0xFFE0A816);
    return const Color(0xFFE85B3D);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final target = percent.clamp(0.0, 100.0);
    final track = t.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: target),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      builder: (context, value, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.chip),
          child: SizedBox(
            height: height ?? 6,
            child: LinearProgressIndicator(
              value: value / 100,
              backgroundColor: track,
              valueColor: AlwaysStoppedAnimation<Color>(colorFor(value)),
            ),
          ),
        );
      },
    );
  }
}
