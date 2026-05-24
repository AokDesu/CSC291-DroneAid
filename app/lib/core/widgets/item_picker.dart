// Public API frozen per #23 / ADR-0003. Body filled in #26.

import 'package:flutter/material.dart';

class CatalogItem {
  const CatalogItem({
    required this.id,
    required this.name,
    required this.unit,
    this.stockQty,
  });

  final String id;
  final String name;
  final String unit;
  final int? stockQty;
}

class CartLine {
  const CartLine({
    required this.itemId,
    required this.qty,
  });

  final String itemId;
  final int qty;
}

class ItemPicker extends StatelessWidget {
  const ItemPicker({
    super.key,
    required this.items,
    required this.onChanged,
  });

  final List<CatalogItem> items;
  final ValueChanged<List<CartLine>> onChanged;

  @override
  Widget build(BuildContext context) {
    return const Text('ItemPicker placeholder');
  }
}
