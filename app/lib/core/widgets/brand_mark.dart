// Brand glyph + wordmark used in every shell AppBar.
// Stand-in icon per plan Q6: Icons.hub_outlined tinted teal.

import 'package:flutter/material.dart';

import '../tokens.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.suffix,
    this.size = 20,
  });

  /// Inline trailing wordmark suffix such as " · Admin".
  final String? suffix;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final brand = t.colorScheme.primary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.hub_outlined, color: brand, size: size + 2),
        const SizedBox(width: AppSpacing.sm),
        Text(
          'DroneAid',
          style: t.textTheme.titleLarge?.copyWith(
            fontSize: size - 1,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        if (suffix != null)
          Text(
            suffix!,
            style: t.textTheme.titleMedium?.copyWith(
              fontSize: size - 4,
              fontWeight: FontWeight.w500,
              color: t.colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
      ],
    );
  }
}
