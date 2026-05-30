// 40×40 rounded tile with a tinted background + category icon. Used as the
// leading widget for catalog rows, queue cards, inventory items, history rows.

import 'package:flutter/material.dart';

import '../theme_extensions.dart';
import '../tokens.dart';

class CategoryIconTile extends StatelessWidget {
  const CategoryIconTile({
    super.key,
    required this.catalogId,
    this.size = 40,
    this.icon,
  });

  /// Optional override — defaults to a Material icon picked by catalogId.
  final IconData? icon;
  final String catalogId;
  final double size;

  static IconData iconFor(String catalogId) {
    final k = catalogId.toLowerCase();
    if (k.contains('food')) return Icons.fastfood_outlined;
    if (k.contains('water')) return Icons.water_drop_outlined;
    if (k.contains('medical') || k.contains('med')) return Icons.medical_services_outlined;
    if (k.contains('baby') || k.contains('formula')) return Icons.child_friendly_outlined;
    if (k.contains('blanket')) return Icons.bed_outlined;
    if (k.contains('flash') || k.contains('light')) return Icons.flashlight_on_outlined;
    return Icons.inventory_2_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final tints = context.categoryTints;
    final bg = tints.tintFor(catalogId);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.iconTile),
      ),
      alignment: Alignment.center,
      child: Icon(
        icon ?? iconFor(catalogId),
        size: size * 0.5,
        color: tints.foreground,
      ),
    );
  }
}
