// Tiny role pill (USER / ADMIN) for profile headers and inline wordmark.
// Spec C-16.

import 'package:flutter/material.dart';

import '../tokens.dart';

class RolePill extends StatelessWidget {
  const RolePill({super.key, required this.role, this.dense = false});

  final String role;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isAdmin = role.toLowerCase() == 'admin';
    final bg = isAdmin
        ? t.colorScheme.primary.withValues(alpha: 0.12)
        : t.colorScheme.surfaceContainerHighest;
    final fg = isAdmin
        ? t.colorScheme.primary
        : t.colorScheme.onSurfaceVariant;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 6 : 8,
        vertical: dense ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(
          color: fg,
          fontSize: dense ? 10 : 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
