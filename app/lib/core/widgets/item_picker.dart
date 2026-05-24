// Public API frozen per #23 / ADR-0003.

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

class ItemPicker extends StatefulWidget {
  const ItemPicker({
    super.key,
    required this.items,
    required this.onChanged,
  });

  final List<CatalogItem> items;
  final ValueChanged<List<CartLine>> onChanged;

  @override
  State<ItemPicker> createState() => _ItemPickerState();
}

class _ItemPickerState extends State<ItemPicker> {
  final Map<String, int> _qty = {};

  void _setQty(String id, int next) {
    setState(() {
      if (next <= 0) {
        _qty.remove(id);
      } else {
        _qty[id] = next;
      }
    });
    final lines = _qty.entries
        .map((e) => CartLine(itemId: e.key, qty: e.value))
        .toList(growable: false);
    widget.onChanged(lines);
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: widget.items.length,
      itemBuilder: (_, i) {
        final item = widget.items[i];
        final qty = _qty[item.id] ?? 0;
        final stockLeft = item.stockQty;
        final canAdd = stockLeft == null || qty < stockLeft;
        return ListTile(
          title: Text(item.name),
          subtitle: Text(item.unit),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove),
                onPressed: qty > 0 ? () => _setQty(item.id, qty - 1) : null,
              ),
              SizedBox(
                width: 32,
                child: Text(
                  '$qty',
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: canAdd ? () => _setQty(item.id, qty + 1) : null,
              ),
            ],
          ),
        );
      },
    );
  }
}
