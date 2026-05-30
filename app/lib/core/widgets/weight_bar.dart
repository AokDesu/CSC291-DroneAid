// Live cart weight vs drone-max gauge. Spec C-11.

import 'package:flutter/material.dart';

import '../theme_extensions.dart';
import '../tokens.dart';

class WeightBar extends StatelessWidget {
  const WeightBar({
    super.key,
    required this.currentKg,
    this.maxKg = 6.0,
  });

  final double currentKg;
  final double maxKg;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final pct = (currentKg / maxKg).clamp(0.0, 1.0);
    final over = currentKg > maxKg;
    final status = context.statusColors;
    final fill = over
        ? status.urgentBg
        : (pct > 0.85 ? status.deliveredFg : t.colorScheme.primary);

    final muted = t.colorScheme.onSurface.withValues(alpha: 0.55);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Total weight',
              style: t.textTheme.labelLarge?.copyWith(color: muted),
            ),
            const Spacer(),
            Text(
              '${currentKg.toStringAsFixed(1)} / ${maxKg.toStringAsFixed(1)} kg',
              style: t.textTheme.labelLarge?.copyWith(
                color: over ? status.urgentBg : t.colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.chip),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 8,
            backgroundColor:
                t.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
            valueColor: AlwaysStoppedAnimation<Color>(fill),
          ),
        ),
      ],
    );
  }
}
