// Riverpod providers for P-A-07 inventory. Streams the admin's full catalog
// view (active + inactive items, ordered by name). The user-side P-U-03
// catalog provider should filter to `active == true` separately.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'catalog_item.dart';

final adminCatalogStreamProvider = StreamProvider<List<CatalogItem>>((ref) {
  final col = FirebaseFirestore.instance.collection('catalog');
  return col.orderBy('name').snapshots().map(
        (snap) => snap.docs.map(CatalogItem.fromSnap).toList(growable: false),
      );
});
