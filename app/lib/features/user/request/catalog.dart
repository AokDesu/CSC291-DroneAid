// User-side catalog model + provider for P-U-03.
// Streams only `active == true` items so out-of-stock or deactivated rows
// stay out of the user's catalog (admin still sees them via P-A-07).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CatalogEntry {
  const CatalogEntry({
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

  bool get outOfStock => stock <= 0;

  factory CatalogEntry.fromSnap(
    QueryDocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final data = snap.data();
    return CatalogEntry(
      id: snap.id,
      name: (data['name'] as String?) ?? snap.id,
      weightKg: (data['weightKg'] as num?)?.toDouble() ?? 0,
      stock: (data['stock'] as num?)?.toInt() ?? 0,
      active: (data['active'] as bool?) ?? true,
      icon: data['icon'] as String?,
    );
  }
}

/// Streams only `active == true` items, ordered by name. Composite index is
/// not required for an equality-only `where` plus one `orderBy`.
final activeCatalogProvider = StreamProvider<List<CatalogEntry>>((ref) {
  final col = FirebaseFirestore.instance.collection('catalog');
  return col
      .where('active', isEqualTo: true)
      .orderBy('name')
      .snapshots()
      .map(
        (snap) =>
            snap.docs.map(CatalogEntry.fromSnap).toList(growable: false),
      );
});
