// Eyebrow + heading + subtitle stack used at the top of every primary page.
// Mirrors the `P-U-03 · REQUEST` / `Request supplies` / subtitle layout in
// docs/prototype-screens/.

import 'package:flutter/material.dart';

import '../theme_extensions.dart';
import '../tokens.dart';

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.lg,
      AppSpacing.md,
      AppSpacing.sm,
    ),
  });

  final String eyebrow;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final text = context.appText;
    final subtitleStyle = t.textTheme.bodyMedium?.copyWith(height: 1.35);

    final stack = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(eyebrow.toUpperCase(), style: text.eyebrow),
        const SizedBox(height: AppSpacing.sm),
        Text(
          title,
          style: t.textTheme.headlineSmall?.copyWith(fontSize: 26),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xs + 2),
          Text(subtitle!, style: subtitleStyle),
        ],
      ],
    );

    return Padding(
      padding: padding,
      child: trailing == null
          ? stack
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: stack),
                trailing!,
              ],
            ),
    );
  }
}
