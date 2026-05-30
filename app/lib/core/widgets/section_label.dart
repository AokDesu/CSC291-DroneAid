// Tiny uppercase tracked gray label that introduces a section (CATALOG,
// DELIVERY PIN, PRIORITY, ACTIVE, PENDING, ...).

import 'package:flutter/material.dart';

import '../theme_extensions.dart';
import '../tokens.dart';

class SectionLabel extends StatelessWidget {
  const SectionLabel(
    this.text, {
    super.key,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.md,
      AppSpacing.md,
      AppSpacing.sm,
    ),
  });

  final String text;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        text.toUpperCase(),
        style: context.appText.sectionLabel,
      ),
    );
  }
}
