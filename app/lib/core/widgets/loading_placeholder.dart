// Centered spinner + accessible label. Replaces bare
// `Center(child: CircularProgressIndicator())` on top-level pages so
// screen readers announce something meaningful while data loads.

import 'package:flutter/material.dart';

class LoadingPlaceholder extends StatelessWidget {
  const LoadingPlaceholder({super.key, this.label = 'Loading…'});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: label,
      liveRegion: true,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
