// Domain model for `catalog/{itemId}` docs. Shared by P-A-07 (admin
// inventory) and any future consumer that needs the full catalog shape
// including the `active` flag and stock. Mirrors the seed schema in
// functions/src/seed/seedCatalog.ts.

import 'package:cloud_firestore/cloud_firestore.dart';

class CatalogItem {
  const CatalogItem({
    required this.id,
    required this.name,
    required this.weightKg,
    required this.stock,
    required this.active,
    this.icon,
  });

  final String id;
  final String name;
  final double weightKg;
  final int stock;
  final bool active;
  final String? icon;

  factory CatalogItem.fromSnap(
    QueryDocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final data = snap.data();
    return CatalogItem(
      id: snap.id,
      name: (data['name'] as String?) ?? snap.id,
      weightKg: (data['weightKg'] as num?)?.toDouble() ?? 0,
      stock: (data['stock'] as num?)?.toInt() ?? 0,
      active: (data['active'] as bool?) ?? true,
      icon: data['icon'] as String?,
    );
  }

  static const lowStockThreshold = 5;

  bool get isLowStock => stock < lowStockThreshold;
}
